import Foundation

/// Размер изображения в пикселях.
public struct PixelSize: Equatable, Sendable {

  /// Ширина в пикселях.
  public let width: Int

  /// Высота в пикселях.
  public let height: Int

  /// Создаёт размер.
  /// - Parameters:
  ///   - width: ширина в пикселях.
  ///   - height: высота в пикселях.
  public init(width: Int, height: Int) {
    self.width = width
    self.height = height
  }
}

/// Снимок экрана, найденный в файловой системе.
///
/// Приложение эти файлы не создаёт и не хранит — оно их только читает, поэтому
/// идентичность записи задаёт путь, а не собственный идентификатор.
public struct Screenshot: Identifiable, Equatable, Sendable {

  /// Путь к файлу. Он же идентичность записи.
  public let id: URL

  /// Имя файла для показа в карточке.
  public let name: String

  /// Размер изображения в пикселях.
  public let pixelSize: PixelSize

  /// Вес файла в байтах.
  public let byteSize: Int

  /// Момент создания файла.
  public let createdAt: Date

  /// Создаёт запись о снимке экрана.
  /// - Parameters:
  ///   - id: путь к файлу.
  ///   - name: имя файла.
  ///   - pixelSize: размер изображения.
  ///   - byteSize: вес файла в байтах.
  ///   - createdAt: момент создания.
  public init(id: URL, name: String, pixelSize: PixelSize, byteSize: Int, createdAt: Date) {
    self.id = id
    self.name = name
    self.pixelSize = pixelSize
    self.byteSize = byteSize
    self.createdAt = createdAt
  }
}
