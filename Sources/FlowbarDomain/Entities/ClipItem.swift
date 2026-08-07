import Foundation

/// Вид скопированного содержимого.
///
/// Влияет только на иконку и подпись в списке, поэтому ошибка определения не критична —
/// спека §8.1.
public enum ClipKind: String, CaseIterable, Sendable {

  /// Обычный текст.
  case text

  /// Ссылка целиком.
  case link

  /// Фрагмент кода.
  case code

  /// Растровое изображение.
  case image

  /// Цвет в любой записи: hex, `rgb()`, `oklch()`.
  case color

  /// Почтовый адрес.
  case address

  /// Путь в файловой системе.
  case path

  /// Идентификатор, хеш или токен — строка без пробелов, читаемая как значение.
  case value
}

/// Полезная нагрузка записи в истории.
public enum ClipPayload: Equatable, Sendable {

  /// Текст, который кладётся в пастборд как есть.
  case string(String)

  /// Файл изображения в хранилище блобов.
  case imageFile(URL)
}

/// Запись в истории копирований.
public struct ClipItem: Identifiable, Equatable, Sendable {

  /// Идентификатор записи.
  public let id: UUID

  /// Вид содержимого.
  public let kind: ClipKind

  /// Однострочное превью для списка.
  public let preview: String

  /// Что именно вернётся в пастборд при копировании.
  public let payload: ClipPayload

  /// Имя приложения, из которого скопировали.
  public let sourceApp: String

  /// Момент попадания в историю.
  public let capturedAt: Date

  /// Создаёт запись истории.
  /// - Parameters:
  ///   - id: идентификатор записи.
  ///   - kind: вид содержимого.
  ///   - preview: однострочное превью.
  ///   - payload: содержимое для обратной записи в пастборд.
  ///   - sourceApp: имя приложения-источника.
  ///   - capturedAt: момент попадания в историю.
  public init(
    id: UUID,
    kind: ClipKind,
    preview: String,
    payload: ClipPayload,
    sourceApp: String,
    capturedAt: Date
  ) {
    self.id = id
    self.kind = kind
    self.preview = preview
    self.payload = payload
    self.sourceApp = sourceApp
    self.capturedAt = capturedAt
  }
}
