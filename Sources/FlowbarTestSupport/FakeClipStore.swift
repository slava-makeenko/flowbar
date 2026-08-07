import FlowbarDomain
import Foundation

/// Хранилище истории копирований в памяти.
public actor FakeClipStore: ClipStoring {

  /// Записи, свежие первыми.
  public private(set) var saved: [ClipItem]

  /// Создаёт хранилище.
  /// - Parameter saved: начальное содержимое, свежие первыми.
  public init(saved: [ClipItem] = []) {
    self.saved = saved
  }

  /// Кладёт запись в начало списка.
  /// - Parameter item: запись.
  public func save(_ item: ClipItem) {
    saved.insert(item, at: 0)
  }

  /// Все записи, свежие первыми.
  /// - Returns: содержимое хранилища.
  public func all() -> [ClipItem] { saved }

  /// Записи строго раньше указанного момента.
  /// - Parameter date: граница отбора.
  /// - Returns: подходящие записи.
  public func items(capturedBefore date: Date) -> [ClipItem] {
    saved.filter { $0.capturedAt < date }
  }

  /// Удаляет записи по идентификаторам.
  /// - Parameter ids: идентификаторы.
  public func remove(ids: [UUID]) {
    saved.removeAll { ids.contains($0.id) }
  }
}

/// Хранилище растров в памяти.
public actor FakeBlobStore: BlobStoring {

  /// Пути, выданные при сохранении, по идентификатору записи.
  public private(set) var stored: [UUID: URL] = [:]

  /// Пути, для которых просили удаление, в порядке вызовов.
  public private(set) var removed: [URL] = []

  private let succeeds: Bool

  /// Создаёт хранилище.
  /// - Parameter succeeds: отдавать ли путь при сохранении.
  public init(succeeds: Bool = true) {
    self.succeeds = succeeds
  }

  /// Отдаёт фиктивный путь; на диск ничего не пишет.
  /// - Parameters:
  ///   - data: растр, содержимое не используется.
  ///   - id: идентификатор записи.
  /// - Returns: путь или `nil`, если хранилище создано неуспешным.
  public func store(_ data: Data, for id: UUID) -> URL? {
    guard succeeds else { return nil }
    let url = URL(fileURLWithPath: "/blobs/\(id.uuidString).png")
    stored[id] = url
    return url
  }

  /// Запоминает путь в `removed`; с диском не работает.
  /// - Parameter url: путь к файлу.
  public func remove(at url: URL) {
    removed.append(url)
  }
}
