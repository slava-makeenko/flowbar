import FlowbarData
import FlowbarDomain
import FlowbarPresentation
import FlowbarUI

/// Единственное место, где встречаются конкретные типы: регламент §5, DIP.
///
/// Синглтонов в проекте нет — всё, что нужно модулям, собирается здесь и передаётся
/// через инициализаторы.
@MainActor
final class CompositionRoot {

  private let clock: any FlowbarDomain.Clock = SystemClock()
  private let shellState = ShellState()
  private var shell: NotchWindowController?

  /// Поднимает приложение.
  func start() {
    _ = clock
    let shell = NotchWindowController(state: shellState)
    shell.start()
    self.shell = shell
  }
}
