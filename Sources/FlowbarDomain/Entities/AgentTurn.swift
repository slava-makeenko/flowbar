import Foundation

/// Состояние хода в сессии агента.
public enum TurnState: Equatable, Sendable {

  /// Ход идёт: агент думает или выполняет инструменты.
  case working

  /// Ход кончился: агент ждёт следующего запроса.
  case waiting
}

/// Изменение транскрипта сессии.
public struct TranscriptChange: Equatable, Sendable {

  /// Чей транскрипт.
  public let agent: Agent

  /// Сессия — путь к файлу транскрипта.
  public let session: String

  /// Транскрипт субагента: конец его хода — не конец работы.
  public let isSubagent: Bool

  /// Последний маркер хода в хвосте; `nil`, если маркера в хвосте нет.
  public let turn: TurnState?

  /// Создаёт изменение.
  /// - Parameters:
  ///   - agent: чей транскрипт.
  ///   - session: путь к файлу транскрипта.
  ///   - isSubagent: транскрипт субагента.
  ///   - turn: последний маркер хода.
  public init(agent: Agent, session: String, isSubagent: Bool, turn: TurnState?) {
    self.agent = agent
    self.session = session
    self.isSubagent = isSubagent
    self.turn = turn
  }
}
