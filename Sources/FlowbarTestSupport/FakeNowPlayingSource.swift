import FlowbarDomain
import Foundation

/// Источник метаданных с заранее заданным ответом.
public struct FakeNowPlayingSource: NowPlayingReading {

  private let answer: NowPlaying

  /// Создаёт источник.
  /// - Parameter answer: что отвечать на любой запрос.
  public init(answer: NowPlaying) {
    self.answer = answer
  }

  /// Отдаёт заданный ответ.
  /// - Returns: ответ, заданный при создании.
  public func current() async -> NowPlaying { answer }
}

/// Управление воспроизведением, запоминающее вызовы.
public actor FakePlaybackController: PlaybackControlling {

  /// Команды в порядке поступления.
  public private(set) var commands: [String] = []

  /// Создаёт управление.
  public init() {}

  /// Запоминает переключение.
  public func toggle() { commands.append("toggle") }

  /// Запоминает переход вперёд.
  public func next() { commands.append("next") }

  /// Запоминает переход назад.
  public func previous() { commands.append("previous") }
}
