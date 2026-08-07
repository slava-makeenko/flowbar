import FlowbarDomain
import Foundation

/// Хранилище быстрых вставок в JSON-файле.
///
/// База здесь не нужна: список ведётся руками и по объёму микроскопический.
public actor JSONSnippetStore: SnippetStoring {

  private let fileURL: URL
  private var cache: [Snippet]?

  /// Создаёт хранилище.
  /// - Parameter directory: каталог, в котором лежит файл со вставками.
  public init(directory: URL) {
    self.fileURL = directory.appending(path: "snippets.json")
  }

  /// Все вставки в порядке показа.
  /// - Returns: содержимое файла; пустой список, если файла ещё нет.
  public func all() -> [Snippet] {
    if let cache { return cache }
    guard let data = try? Data(contentsOf: fileURL),
      let stored = try? JSONDecoder().decode([Snippet].self, from: data)
    else {
      cache = []
      return []
    }
    cache = stored
    return stored
  }

  /// Заменяет весь список и пишет его на диск.
  ///
  /// Запись атомарная: обрыв на середине оставит прежний файл, а не половину нового.
  /// - Parameter snippets: новый список.
  public func replaceAll(with snippets: [Snippet]) {
    cache = snippets
    guard let data = try? JSONEncoder().encode(snippets) else { return }
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? data.write(to: fileURL, options: .atomic)
  }
}
