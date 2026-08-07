import Foundation

/// Вид быстрой вставки.
public enum SnippetKind: String, CaseIterable, Codable, Sendable {

  /// Адрес электронной почты.
  case email

  /// Тег вида `#design-review`.
  case tag

  /// Телефонный номер.
  case phone
}

/// Часто используемая вставка, заведённая пользователем вручную.
///
/// С `ClipItem` общего предка не имеет намеренно: у копии источником служит система и есть
/// срок жизни, вставка создаётся руками и живёт вечно. Регламент §6.
public struct Snippet: Identifiable, Equatable, Codable, Sendable {

  /// Идентификатор вставки.
  public let id: UUID

  /// Вид вставки.
  public var kind: SnippetKind

  /// Значение, которое кладётся в пастборд.
  public var value: String

  /// Необязательная подпись под значением.
  public var note: String

  /// Создаёт вставку.
  /// - Parameters:
  ///   - id: идентификатор.
  ///   - kind: вид вставки.
  ///   - value: значение.
  ///   - note: подпись, по умолчанию пустая.
  public init(id: UUID, kind: SnippetKind, value: String, note: String = "") {
    self.id = id
    self.kind = kind
    self.value = value
    self.note = note
  }
}
