import Foundation
import SQLite3

/// Перенос данных из контейнера песочницы. ADR-0016.
///
/// Под песочницей Application Support и настройки жили в
/// `~/Library/Containers/<bundle id>/Data`. Без неё приложение ищет их в домашней
/// библиотеке — и без переноса история, картинки и вставки выглядели бы пропавшими.
/// Контейнер не удаляется: откат к песочнице остаётся возможным.
public enum SandboxContainerMigration {

  /// Ключи настроек, которые не переносятся: закладки на папки агентов больше не нужны,
  /// а `NS…` — состояние системных панелей.
  private static let skippedKeyPrefixes = ["agentFolderBookmark.", "NS"]

  /// Переносит данные, если их ещё нет на новом месте.
  ///
  /// Повторный вызов ничего не делает: признак — существование папки назначения.
  /// - Parameters:
  ///   - bundleIdentifier: идентификатор приложения.
  ///   - supportFolderName: имя папки приложения в Application Support.
  ///   - defaults: куда переносить настройки.
  public static func migrateIfNeeded(
    bundleIdentifier: String,
    supportFolderName: String,
    defaults: UserDefaults = .standard
  ) {
    let fileManager = FileManager.default
    let library = fileManager.homeDirectoryForCurrentUser.appending(path: "Library")
    let container = library.appending(path: "Containers/\(bundleIdentifier)/Data/Library")

    let source = container.appending(path: "Application Support/\(supportFolderName)")
    let destination = library.appending(path: "Application Support/\(supportFolderName)")
    guard
      fileManager.fileExists(atPath: source.path),
      !fileManager.fileExists(atPath: destination.path)
    else { return }

    do {
      try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      try fileManager.copyItem(at: source, to: destination)
    } catch {
      return
    }
    rewriteImagePaths(
      in: destination.appending(path: "clips.sqlite"),
      from: source.path,
      to: destination.path
    )
    importDefaults(
      from: container.appending(path: "Preferences/\(bundleIdentifier).plist"),
      into: defaults
    )
  }

  /// История хранит абсолютные пути картинок — они указывали внутрь контейнера.
  private static func rewriteImagePaths(in database: URL, from old: String, to new: String) {
    var handle: OpaquePointer?
    guard sqlite3_open(database.path, &handle) == SQLITE_OK else {
      sqlite3_close(handle)
      return
    }
    defer { sqlite3_close(handle) }

    let sql = """
      UPDATE clips SET payload_value = ? || substr(payload_value, ?)
      WHERE payload_kind = 'imageFile' AND substr(payload_value, 1, ?) = ?
      """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return }
    defer { sqlite3_finalize(statement) }

    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    // `substr` считает символы, а не байты: длина — в скалярах Unicode.
    let oldLength = Int32(old.unicodeScalars.count)
    sqlite3_bind_text(statement, 1, new, -1, transient)
    sqlite3_bind_int(statement, 2, oldLength + 1)
    sqlite3_bind_int(statement, 3, oldLength)
    sqlite3_bind_text(statement, 4, old, -1, transient)
    sqlite3_step(statement)
  }

  /// Настройки переносятся по ключам и только туда, где их ещё нет.
  private static func importDefaults(from plist: URL, into defaults: UserDefaults) {
    guard let stored = NSDictionary(contentsOf: plist) as? [String: Any] else { return }
    for (key, value) in stored
    where !skippedKeyPrefixes.contains(where: key.hasPrefix) && defaults.object(forKey: key) == nil
    {
      defaults.set(value, forKey: key)
    }
  }
}
