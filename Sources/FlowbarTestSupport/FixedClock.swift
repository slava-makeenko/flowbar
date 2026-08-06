import FlowbarDomain
import Foundation

/// Часы, всегда отдающие один и тот же момент времени.
///
/// Логики не содержит намеренно: фейк, который умеет принимать решения, скрывает ошибку
/// в тесте вместо того, чтобы её показать.
public struct FixedClock: FlowbarDomain.Clock {

  /// Зафиксированный момент времени.
  public let now: Date

  /// Создаёт часы, зафиксированные на указанном моменте.
  /// - Parameter now: момент, который часы будут отдавать всегда.
  public init(now: Date) {
    self.now = now
  }
}
