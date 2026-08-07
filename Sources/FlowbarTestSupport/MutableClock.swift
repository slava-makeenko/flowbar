import FlowbarDomain
import Foundation

/// Часы с изменяемым временем.
///
/// Нужны там, где проверяется, что время записи обновилось: `FixedClock` для этого
/// не годится, а настоящие часы сделали бы тест зависимым от скорости машины.
///
/// Пометка `@unchecked Sendable` безопасна по назначению: часы живут внутри одного теста
/// и меняются последовательно, без гонок.
public final class MutableClock: FlowbarDomain.Clock, @unchecked Sendable {

  /// Текущий момент. Меняется прямо в тесте.
  public var now: Date

  /// Создаёт часы.
  /// - Parameter now: начальный момент.
  public init(now: Date) {
    self.now = now
  }
}
