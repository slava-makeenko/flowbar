import Foundation

/// Хранилище быстрых вставок.
///
/// Объём микроскопический, поэтому база не нужна — хватает файла.
public protocol SnippetStoring: Sendable {

  /// Все вставки в порядке показа.
  func all() async -> [Snippet]

  /// Заменяет весь список.
  /// - Parameter snippets: новый список.
  func replaceAll(with snippets: [Snippet]) async
}
