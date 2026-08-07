import Foundation

/// Приложение, из которого пришло содержимое пастборда.
public struct SourceApp: Equatable, Sendable {

  /// Отображаемое имя: «Notes», «Safari», «VS Code».
  public let name: String

  /// Идентификатор бандла, если его удалось определить.
  public let bundleIdentifier: String?

  /// Создаёт описание приложения-источника.
  /// - Parameters:
  ///   - name: отображаемое имя.
  ///   - bundleIdentifier: идентификатор бандла, если известен.
  public init(name: String, bundleIdentifier: String? = nil) {
    self.name = name
    self.bundleIdentifier = bundleIdentifier
  }
}

/// Снимок содержимого пастборда, независимый от AppKit.
///
/// Домен не знает про `NSPasteboard`: адаптер переводит пастборд в эту структуру,
/// и вся классификация работает уже с ней.
public struct PasteboardItem: Equatable, Sendable {

  /// Текстовое представление, если оно есть.
  public let text: String?

  /// Ссылка на файл, если в пастборде лежит файл.
  public let fileURL: URL?

  /// Растр, если в пастборде лежит изображение.
  public let imageData: Data?

  /// Содержимое помечено как конфиденциальное — `org.nspasteboard.ConcealedType`.
  ///
  /// Так менеджеры паролей помечают то, что не должно попадать в истории копирований.
  public let isConcealed: Bool

  /// Содержимое помечено как временное — `org.nspasteboard.TransientType`.
  public let isTransient: Bool

  /// Приложение-источник.
  public let sourceApp: SourceApp

  /// Создаёт снимок содержимого пастборда.
  /// - Parameters:
  ///   - text: текстовое представление.
  ///   - fileURL: ссылка на файл.
  ///   - imageData: растр.
  ///   - isConcealed: пометка конфиденциальности.
  ///   - isTransient: пометка временности.
  ///   - sourceApp: приложение-источник.
  public init(
    text: String? = nil,
    fileURL: URL? = nil,
    imageData: Data? = nil,
    isConcealed: Bool = false,
    isTransient: Bool = false,
    sourceApp: SourceApp
  ) {
    self.text = text
    self.fileURL = fileURL
    self.imageData = imageData
    self.isConcealed = isConcealed
    self.isTransient = isTransient
    self.sourceApp = sourceApp
  }
}
