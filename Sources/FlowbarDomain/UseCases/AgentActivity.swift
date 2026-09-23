import Foundation

/// Правило «агент работает»: с последней записи в его транскрипт прошло меньше окна
/// удержания.
///
/// Отдельного сигнала «работаю» у агентов нет, зато любой их клиент дописывает транскрипт
/// по ходу работы. Паузы между записями длиннее 20 с — около 5 % у Claude Code и 2 %
/// у Codex, и в них входит простой, пока пользователь пишет следующий запрос. ADR-0013.
public struct AgentActivity: Equatable, Sendable {

  /// Окно удержания по умолчанию.
  public static let defaultHoldWindow: TimeInterval = 20

  /// Сколько агент считается работающим после последней записи.
  public let holdWindow: TimeInterval

  private var lastWrites: [Agent: Date] = [:]

  /// Создаёт правило.
  /// - Parameter holdWindow: окно удержания.
  public init(holdWindow: TimeInterval = AgentActivity.defaultHoldWindow) {
    self.holdWindow = holdWindow
  }

  /// Отмечает запись в транскрипт.
  /// - Parameters:
  ///   - agent: чей транскрипт изменился.
  ///   - moment: момент записи.
  public mutating func recordWrite(by agent: Agent, at moment: Date) {
    lastWrites[agent] = max(lastWrites[agent] ?? moment, moment)
  }

  /// Агенты, работающие в указанный момент.
  /// - Parameter now: текущий момент.
  /// - Returns: множество работающих агентов.
  public func working(at now: Date) -> Set<Agent> {
    Set(lastWrites.filter { now < $0.value + holdWindow }.keys)
  }

  /// Когда множество работающих поменяется само, без новых записей.
  ///
  /// Нужен, чтобы гасить индикатор разовым таймером ровно в срок, а не опросом.
  /// - Parameter now: текущий момент.
  /// - Returns: ближайший момент затухания или `nil`, если гаснуть некому.
  public func nextChange(after now: Date) -> Date? {
    lastWrites.values.map { $0 + holdWindow }.filter { $0 > now }.min()
  }
}
