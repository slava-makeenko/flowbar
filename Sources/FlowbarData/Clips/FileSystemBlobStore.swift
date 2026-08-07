import FlowbarDomain
import Foundation

/// Растры истории копирований файлами на диске.
public actor FileSystemBlobStore: BlobStoring {

  private let directory: URL

  /// Создаёт хранилище.
  /// - Parameter directory: каталог для файлов.
  public init(directory: URL) {
    self.directory = directory
  }

  /// Сохраняет растр и возвращает путь к нему.
  /// - Parameters:
  ///   - data: растр.
  ///   - id: идентификатор записи истории.
  /// - Returns: путь к файлу или `nil`, если записать не удалось.
  public func store(_ data: Data, for id: UUID) -> URL? {
    let url = directory.appending(path: "\(id.uuidString).png")
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
  }

  /// Удаляет файл.
  /// - Parameter url: путь к файлу.
  public func remove(at url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
