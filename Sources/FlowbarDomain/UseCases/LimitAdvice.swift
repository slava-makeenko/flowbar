import Foundation

/// Совет переключиться на другого агента. ADR-0015.
///
/// Workflow у агентов общий, поэтому когда у одного окно кончается, полезнее всего знать,
/// что у второго оно свободно.
public struct LimitAdvice: Equatable, Sendable {

  /// С какой доли окно считается почти исчерпанным.
  public static let nearLimitPercent: Double = 90

  /// Выше какой доли окно второго агента уже не предлагается.
  public static let alternativeMaximumPercent: Double = 80

  /// Агент, у которого окно кончается.
  public let from: Agent

  /// Агент, на которого стоит переключиться.
  public let to: Agent

  /// Окно второго агента той же длины.
  public let window: UsageWindow

  /// Ищет совет.
  ///
  /// Окно агента кончается, если по прогнозу исчерпается до сброса или уже занято
  /// не меньше чем на 90 %. Второй агент подходит, если его окно той же длины занято меньше
  /// чем на 80 % и по прогнозу не кончается. Устаревшие снимки не участвуют ни с одной
  /// стороны: по ним нельзя сказать ни что окно кончается, ни что оно свободно.
  /// - Parameters:
  ///   - usages: последние снимки агентов.
  ///   - now: текущий момент.
  /// - Returns: первый найденный совет или `nil`.
  public static func find(in usages: [AgentUsage], at now: Date) -> LimitAdvice? {
    let current = usages.filter { !$0.isOutdated }
    for usage in current {
      for window in usage.windows where isRunningOut(window, of: usage, at: now) {
        for other in current where other.agent != usage.agent {
          guard
            let alternative = other.windows.first(where: { $0.duration == window.duration }),
            alternative.usedPercent(at: now) < alternativeMaximumPercent,
            !isRunningOut(alternative, of: other, at: now)
          else { continue }
          return LimitAdvice(from: usage.agent, to: other.agent, window: alternative)
        }
      }
    }
    return nil
  }

  private static func isRunningOut(
    _ window: UsageWindow,
    of usage: AgentUsage,
    at now: Date
  ) -> Bool {
    if window.usedPercent(at: now) >= nearLimitPercent { return true }
    guard now < window.resetsAt, case .runsOut = window.forecast(measuredAt: usage.measuredAt)
    else { return false }
    return true
  }
}
