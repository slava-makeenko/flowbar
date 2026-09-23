import Foundation

/// Агент, чьи лимиты и работу показывает приложение.
public enum Agent: String, CaseIterable, Sendable {

  /// Claude Code: CLI, вкладка Code в десктопном приложении, расширения IDE.
  case claudeCode

  /// Codex: CLI и десктопное приложение.
  case codex
}

/// Окно лимита: сколько израсходовано и когда счётчик обнулится.
public struct UsageWindow: Equatable, Sendable {

  /// Длина окна: пять часов у сессионного лимита, неделя у недельного.
  public let duration: TimeInterval

  /// Израсходованная доля окна в процентах, от 0 до 100.
  public let usedPercent: Double

  /// Момент сброса счётчика.
  public let resetsAt: Date

  /// Создаёт окно.
  /// - Parameters:
  ///   - duration: длина окна.
  ///   - usedPercent: израсходованная доля в процентах; выход за 0…100 обрезается.
  ///   - resetsAt: момент сброса.
  public init(duration: TimeInterval, usedPercent: Double, resetsAt: Date) {
    self.duration = duration
    self.usedPercent = min(max(usedPercent, 0), 100)
    self.resetsAt = resetsAt
  }

  /// Израсходованная доля на указанный момент.
  ///
  /// Снимок может быть старым, но момент сброса абсолютный: после него окно пустое,
  /// даже если агент с тех пор ничего не записал.
  /// - Parameter now: текущий момент.
  /// - Returns: доля в процентах.
  public func usedPercent(at now: Date) -> Double {
    now >= resetsAt ? 0 : usedPercent
  }
}

/// Последний известный снимок лимитов агента.
public struct AgentUsage: Equatable, Sendable {

  /// Агент.
  public let agent: Agent

  /// Окна лимита, короткие первыми.
  public let windows: [UsageWindow]

  /// Когда снимок сделан. Данные обновляются, только пока агент работает.
  public let measuredAt: Date

  /// Создаёт снимок.
  /// - Parameters:
  ///   - agent: агент.
  ///   - windows: окна лимита в любом порядке.
  ///   - measuredAt: момент снимка.
  public init(agent: Agent, windows: [UsageWindow], measuredAt: Date) {
    self.agent = agent
    self.windows = windows.sorted { $0.duration < $1.duration }
    self.measuredAt = measuredAt
  }
}
