import FlowbarDomain
import Foundation

/// Чтение файлов с диска.
public struct FileSystemFileReader: FileReading {

  /// Создаёт читателя.
  public init() {}

  /// Читает файл целиком.
  /// - Parameter url: путь к файлу.
  /// - Returns: содержимое или `nil`, если файла нет или он недоступен.
  public func data(at url: URL) -> Data? {
    try? Data(contentsOf: url)
  }
}
