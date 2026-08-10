import FlowbarDomain
import Foundation
import SQLite3

/// История копирований в базе SQLite.
///
/// Метаданные живут здесь, растры — файлами рядом: в базе от них только путь.
public actor SQLiteClipStore: ClipStoring {

  /// SQLite обязан скопировать переданную строку: указатель живёт только на время вызова.
  private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  private let connection: DatabaseConnection

  private var database: OpaquePointer? { connection.handle }

  /// Открывает базу, создавая её при первом запуске.
  /// - Parameter fileURL: путь к файлу базы.
  public init(fileURL: URL) {
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    var handle: OpaquePointer?
    if sqlite3_open(fileURL.path, &handle) != SQLITE_OK { handle = nil }
    connection = DatabaseConnection(handle: handle)
    Self.createSchema(in: handle)
  }

  /// Сохраняет запись.
  /// - Parameter item: запись истории.
  public func save(_ item: ClipItem) {
    let sql = """
      INSERT OR REPLACE INTO clips
        (id, kind, preview, payload_kind, payload_value, source_app, captured_at,
         pixel_width, pixel_height)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      """
    withStatement(sql) { statement in
      let payload = Self.encode(item.payload)
      bind(statement, 1, item.id.uuidString)
      bind(statement, 2, item.kind.rawValue)
      bind(statement, 3, item.preview)
      bind(statement, 4, payload.kind)
      bind(statement, 5, payload.value)
      bind(statement, 6, item.sourceApp)
      sqlite3_bind_double(statement, 7, item.capturedAt.timeIntervalSince1970)
      if let size = item.pixelSize {
        sqlite3_bind_int(statement, 8, Int32(size.width))
        sqlite3_bind_int(statement, 9, Int32(size.height))
      } else {
        sqlite3_bind_null(statement, 8)
        sqlite3_bind_null(statement, 9)
      }
      sqlite3_step(statement)
    }
  }

  /// Все записи, свежие первыми.
  /// - Returns: содержимое истории.
  public func all() -> [ClipItem] {
    query("SELECT * FROM clips ORDER BY captured_at DESC")
  }

  /// Записи, попавшие в историю раньше указанного момента.
  /// - Parameter date: граница отбора.
  /// - Returns: просроченные записи.
  public func items(capturedBefore date: Date) -> [ClipItem] {
    query(
      "SELECT * FROM clips WHERE captured_at < ? ORDER BY captured_at DESC",
      bindings: { sqlite3_bind_double($0, 1, date.timeIntervalSince1970) }
    )
  }

  /// Удаляет записи по идентификаторам.
  /// - Parameter ids: идентификаторы записей.
  public func remove(ids: [UUID]) {
    guard !ids.isEmpty else { return }
    let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
    withStatement("DELETE FROM clips WHERE id IN (\(placeholders))") { statement in
      for (offset, id) in ids.enumerated() {
        bind(statement, Int32(offset + 1), id.uuidString)
      }
      sqlite3_step(statement)
    }
  }

  // MARK: - Схема и запросы

  private static func createSchema(in database: OpaquePointer?) {
    let sql = """
      CREATE TABLE IF NOT EXISTS clips (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        preview TEXT NOT NULL,
        payload_kind TEXT NOT NULL,
        payload_value TEXT NOT NULL,
        source_app TEXT NOT NULL,
        captured_at REAL NOT NULL
      );
      CREATE INDEX IF NOT EXISTS clips_captured_at ON clips (captured_at);
      """
    sqlite3_exec(database, sql, nil, nil, nil)

    // Размер картинки добавился позже. У созданной заново базы колонки уже есть,
    // у существующей их надо дописать — повторный ALTER просто вернёт ошибку.
    sqlite3_exec(database, "ALTER TABLE clips ADD COLUMN pixel_width INTEGER", nil, nil, nil)
    sqlite3_exec(database, "ALTER TABLE clips ADD COLUMN pixel_height INTEGER", nil, nil, nil)
  }

  private func query(
    _ sql: String,
    bindings: (OpaquePointer) -> Void = { _ in }
  ) -> [ClipItem] {
    var items: [ClipItem] = []
    withStatement(sql) { statement in
      bindings(statement)
      while sqlite3_step(statement) == SQLITE_ROW {
        if let item = Self.decode(statement) { items.append(item) }
      }
    }
    return items
  }

  private func withStatement(_ sql: String, body: (OpaquePointer) -> Void) {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
      let statement
    else { return }
    defer { sqlite3_finalize(statement) }
    body(statement)
  }

  private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: String) {
    sqlite3_bind_text(statement, index, value, -1, Self.transient)
  }

  // MARK: - Преобразование

  private static func encode(_ payload: ClipPayload) -> (kind: String, value: String) {
    switch payload {
    case .string(let text): ("string", text)
    case .imageFile(let url): ("imageFile", url.path)
    }
  }

  private static func decode(_ statement: OpaquePointer) -> ClipItem? {
    func text(_ column: Int32) -> String {
      guard let raw = sqlite3_column_text(statement, column) else { return "" }
      return String(cString: raw)
    }

    guard let id = UUID(uuidString: text(0)),
      let kind = ClipKind(rawValue: text(1))
    else { return nil }

    let payload: ClipPayload =
      text(3) == "imageFile"
      ? .imageFile(URL(fileURLWithPath: text(4)))
      : .string(text(4))

    let width = Int(sqlite3_column_int(statement, 7))
    let height = Int(sqlite3_column_int(statement, 8))

    return ClipItem(
      id: id,
      kind: kind,
      preview: text(2),
      payload: payload,
      sourceApp: text(5),
      capturedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
      pixelSize: width > 0 && height > 0 ? PixelSize(width: width, height: height) : nil
    )
  }
}

/// Владелец соединения с базой.
///
/// Отдельный класс, а не `deinit` актора: `deinit` не может трогать несендабельное
/// состояние, а `isolated deinit` доступен только с macOS 15.4 — выше целевой 15.0
/// из ADR-0001. Пометка `@unchecked Sendable` безопасна по построению: указатель
/// создаётся в инициализаторе, больше не меняется и используется только изнутри актора.
private final class DatabaseConnection: @unchecked Sendable {

  let handle: OpaquePointer?

  init(handle: OpaquePointer?) {
    self.handle = handle
  }

  deinit {
    sqlite3_close(handle)
  }
}
