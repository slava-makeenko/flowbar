import Foundation

/// Правило «агент работает» по его транскриптам. ADR-0013, ADR-0014.
///
/// Агент работает, если в какой-то его сессии идёт ход и последняя запись моложе окна
/// удержания. Конец хода гасит сессию сразу: его маркер виден в транскрипте, и ждать
/// окно удержания незачем. Окно нужно только для пауз внутри хода — паузы между записями
/// длиннее 20 с бывают у 5 % записей Claude Code и 2 % Codex.
public struct AgentActivity: Equatable, Sendable {

  /// Окно удержания по умолчанию.
  public static let defaultHoldWindow: TimeInterval = 20

  /// Сколько сессия считается работающей после последней записи.
  public let holdWindow: TimeInterval

  private struct Session: Equatable, Sendable {
    let agent: Agent
    var lastWrite: Date
    var turn: TurnState?
  }

  private var sessions: [String: Session] = [:]

  /// Создаёт правило.
  /// - Parameter holdWindow: окно удержания.
  public init(holdWindow: TimeInterval = AgentActivity.defaultHoldWindow) {
    self.holdWindow = holdWindow
  }

  /// Учитывает изменение транскрипта.
  ///
  /// Маркер хода субагента игнорируется: конец его хода — не конец работы родителя,
  /// а запись значит, что родительская сессия работает.
  /// - Parameters:
  ///   - change: изменение.
  ///   - moment: момент записи.
  public mutating func record(_ change: TranscriptChange, at moment: Date) {
    var session =
      sessions[change.session] ?? Session(agent: change.agent, lastWrite: moment, turn: nil)
    session.lastWrite = max(session.lastWrite, moment)
    if !change.isSubagent, let turn = change.turn { session.turn = turn }
    sessions[change.session] = session
    // Затихшие и закончившие ход сессии больше ничего не покажут: иначе словарь рос бы
    // весь день. Служебная строка после конца хода не воскресит сессию — в её хвосте
    // последним маркером всё равно будет конец хода.
    sessions = sessions.filter { isWorking($0.value, at: moment) }
  }

  /// Агенты, работающие в указанный момент.
  /// - Parameter now: текущий момент.
  /// - Returns: множество работающих агентов.
  public func working(at now: Date) -> Set<Agent> {
    Set(sessions.values.filter { isWorking($0, at: now) }.map(\.agent))
  }

  /// Когда множество работающих поменяется само, без новых записей.
  ///
  /// Нужен, чтобы гасить индикатор разовым таймером ровно в срок, а не опросом.
  /// - Parameter now: текущий момент.
  /// - Returns: ближайший момент затухания или `nil`, если гаснуть некому.
  public func nextChange(after now: Date) -> Date? {
    sessions.values
      .filter { $0.turn != .waiting }
      .map { $0.lastWrite + holdWindow }
      .filter { $0 > now }
      .min()
  }

  private func isWorking(_ session: Session, at now: Date) -> Bool {
    session.turn != .waiting && now < session.lastWrite + holdWindow
  }
}
