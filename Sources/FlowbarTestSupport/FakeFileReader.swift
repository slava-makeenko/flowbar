import FlowbarDomain
import Foundation

/// Чтение файлов из памяти.
public actor FakeFileReader: FileReading {

  private let files: [URL: Data]

  /// Создаёт читателя.
  /// - Parameter files: содержимое по путям; отсутствующий путь читается как `nil`.
  public init(files: [URL: Data] = [:]) {
    self.files = files
  }

  /// Отдаёт заранее заданное содержимое.
  /// - Parameter url: путь к файлу.
  /// - Returns: содержимое или `nil`, если путь не задавали.
  public func data(at url: URL) -> Data? { files[url] }
}
