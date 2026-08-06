import FlowbarData
import FlowbarDomain

/// Единственное место, где встречаются конкретные типы: регламент §5, DIP.
///
/// Синглтонов в проекте нет — всё, что нужно модулям, собирается здесь и передаётся
/// через инициализаторы.
@MainActor
final class CompositionRoot {

  private let clock: any FlowbarDomain.Clock = SystemClock()

  /// Поднимает приложение. Окно появляется в фазе 3 пайплайна.
  func start() {
    _ = clock
  }
}
