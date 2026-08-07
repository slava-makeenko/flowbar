import FlowbarDomain
import Foundation

/// Хранилище быстрых вставок в памяти.
public actor FakeSnippetStore: SnippetStoring {

  /// Текущий список вставок.
  public private(set) var snippets: [Snippet]

  /// Создаёт хранилище.
  /// - Parameter snippets: начальное содержимое.
  public init(snippets: [Snippet] = []) {
    self.snippets = snippets
  }

  /// Все вставки в порядке хранения.
  /// - Returns: содержимое хранилища.
  public func all() -> [Snippet] { snippets }

  /// Заменяет весь список.
  /// - Parameter snippets: новый список.
  public func replaceAll(with snippets: [Snippet]) {
    self.snippets = snippets
  }
}
