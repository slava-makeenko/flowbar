import FlowbarData
import FlowbarDomain
import FlowbarPresentation
import FlowbarUI
import Foundation

/// Единственное место, где встречаются конкретные типы: регламент §5, DIP.
///
/// Синглтонов в проекте нет — всё, что нужно модулям, собирается здесь и передаётся
/// через инициализаторы.
@MainActor
final class CompositionRoot {

  private let clock: any FlowbarDomain.Clock = SystemClock()
  private let shellState = ShellState()
  private let feedback = CopyFeedback()
  private var shell: NotchWindowController?

  /// Поднимает приложение.
  func start() {
    _ = clock
    let shell = NotchWindowController(
      state: shellState,
      snippets: makeSnippetsViewModel(),
      feedback: feedback
    )
    shell.start()
    self.shell = shell
  }

  private func makeSnippetsViewModel() -> SnippetsViewModel {
    let store = JSONSnippetStore(directory: Self.supportDirectory)
    return SnippetsViewModel(
      store: store,
      addSnippet: AddSnippet(store: store),
      pasteboard: NSPasteboardAdapter(),
      feedback: feedback
    )
  }

  /// Каталог приложения в Application Support.
  ///
  /// В песочнице путь ведёт внутрь контейнера, снаружи — в домашнюю библиотеку.
  private static var supportDirectory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    return (base.first ?? URL(filePath: NSTemporaryDirectory())).appending(path: "Flowbar")
  }
}
