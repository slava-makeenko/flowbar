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

  /// Прогноз окна при среднем темпе с его начала.
  public enum Forecast: Equatable, Sendable {

    /// При том же темпе окно кончится раньше сброса.
    case runsOut(at: Date)

    /// Окна хватит до сброса.
    case lastsUntilReset
  }

  /// Какая доля окна должна пройти, чтобы темп что-то значил: 15 минут из пяти часов.
  public static let forecastMinimumElapsedShare = 0.05

  /// Прогноз по среднему темпу с начала окна. ADR-0015.
  ///
  /// Окно началось в `resetsAt − duration`; при темпе `usedPercent` за прошедшее время
  /// 100 % наберутся к `начало + прошло × 100 / usedPercent`.
  /// - Parameter measuredAt: момент снимка.
  /// - Returns: прогноз или `nil`, если данных мало, окно пустое, сброшено или исчерпано.
  public func forecast(measuredAt: Date) -> Forecast? {
    let start = resetsAt - duration
    let elapsed = measuredAt.timeIntervalSince(start)
    guard
      measuredAt < resetsAt,
      usedPercent > 0, usedPercent < 100,
      elapsed >= duration * Self.forecastMinimumElapsedShare
    else { return nil }

    let exhaustion = start + elapsed * 100 / usedPercent
    return exhaustion < resetsAt ? .runsOut(at: exhaustion) : .lastsUntilReset
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

  /// Когда агент последний раз писал транскрипт; `nil`, если неизвестно.
  public let lastActivityAt: Date?

  /// Насколько работа может опережать снимок, не делая его устаревшим.
  ///
  /// В терминальной сессии транскрипт пишется раньше, чем statusLine обновит снимок.
  public static let outdatedTolerance: TimeInterval = 2 * 60

  /// Создаёт снимок.
  /// - Parameters:
  ///   - agent: агент.
  ///   - windows: окна лимита в любом порядке.
  ///   - measuredAt: момент снимка.
  ///   - lastActivityAt: последняя запись агента в транскрипт.
  public init(
    agent: Agent,
    windows: [UsageWindow],
    measuredAt: Date,
    lastActivityAt: Date? = nil
  ) {
    self.agent = agent
    self.windows = windows.sorted { $0.duration < $1.duration }
    self.measuredAt = measuredAt
    self.lastActivityAt = lastActivityAt
  }

  /// Снимок заведомо устарел: агент работал после него, а снимок не обновился.
  ///
  /// Так бывает у Claude Code: снимок пишет только statusLine терминального `claude`,
  /// а вкладка Code десктопного приложения её не запускает и тратит лимит молча.
  /// Прогноз и совет по такому снимку вводили бы в заблуждение.
  public var isOutdated: Bool {
    guard let lastActivityAt else { return false }
    return lastActivityAt > measuredAt + Self.outdatedTolerance
  }

  /// Тот же снимок с известной последней работой агента.
  /// - Parameter moment: последняя запись агента в транскрипт.
  /// - Returns: снимок.
  public func withLastActivity(_ moment: Date?) -> AgentUsage {
    AgentUsage(agent: agent, windows: windows, measuredAt: measuredAt, lastActivityAt: moment)
  }
}
