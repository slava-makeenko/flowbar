import Foundation

/// Состояние хода в сессии агента.
public enum TurnState: Equatable, Sendable {

  /// Ход идёт: агент думает или выполняет инструменты.
  case working

  /// Ход кончился: агент ждёт следующего запроса.
  case waiting
}

/// Изменение транскрипта сессии или событие хука агента.
public struct TranscriptChange: Equatable, Sendable {

  /// Откуда известно об изменении.
  public enum Source: Equatable, Sendable {

    /// Запись в транскрипт: ход разобран из его хвоста.
    case transcript

    /// Хук агента: начало и конец хода сообщены явно. ADR-0017.
    case hook
  }

  /// Чей транскрипт.
  public let agent: Agent

  /// Сессия — путь к файлу транскрипта.
  public let session: String

  /// Транскрипт субагента: конец его хода — не конец работы.
  public let isSubagent: Bool

  /// Последний маркер хода; `nil`, если маркера нет.
  public let turn: TurnState?

  /// Откуда известно об изменении.
  public let source: Source

  /// Создаёт изменение.
  /// - Parameters:
  ///   - agent: чей транскрипт.
  ///   - session: путь к файлу транскрипта или идентификатор сессии.
  ///   - isSubagent: транскрипт субагента.
  ///   - turn: последний маркер хода.
  ///   - source: откуда известно об изменении.
  public init(
    agent: Agent,
    session: String,
    isSubagent: Bool,
    turn: TurnState?,
    source: Source = .transcript
  ) {
    self.agent = agent
    self.session = session
    self.isSubagent = isSubagent
    self.turn = turn
    self.source = source
  }
}
