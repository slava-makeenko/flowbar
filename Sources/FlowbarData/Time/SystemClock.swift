import FlowbarDomain
import Foundation

/// Часы, читающие системное время.
public struct SystemClock: FlowbarDomain.Clock {

  /// Создаёт часы.
  public init() {}

  /// Текущий момент системного времени.
  public var now: Date { Date() }
}
