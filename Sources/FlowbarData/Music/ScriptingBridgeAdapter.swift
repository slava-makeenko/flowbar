import FlowbarDomain
import Foundation
import ScriptingBridge

/// Трек в словаре Music.app и Spotify.
///
/// Оба приложения описывают его одинаково, поэтому протокол один. Все члены
/// необязательные: `SBApplication` отвечает на сообщения динамически, и объявленного
/// соответствия у неё нет — пустое расширение ниже как раз это и оформляет.
@objc public protocol ScriptablePlayerTrack {

  /// Название трека.
  @objc optional var name: String { get }

  /// Исполнитель.
  @objc optional var artist: String { get }

  /// Длительность: секунды в Music.app, миллисекунды в Spotify.
  @objc optional var duration: Double { get }
}

/// Приложение-плеер в терминах ScriptingBridge.
@objc public protocol ScriptablePlayer {

  /// Играющий сейчас трек.
  @objc optional var currentTrack: ScriptablePlayerTrack { get }

  /// Позиция внутри трека в секундах.
  @objc optional var playerPosition: Double { get }

  /// Состояние проигрывания четырёхсимвольным кодом.
  @objc optional var playerState: UInt32 { get }

  /// Переключает воспроизведение и паузу.
  @objc optional func playpause()

  /// Следующий трек.
  @objc optional func nextTrack()

  /// Предыдущий трек.
  @objc optional func previousTrack()

  /// Устанавливает позицию внутри трека.
  @objc optional func setPlayerPosition(_ position: Double)
}

extension SBApplication: ScriptablePlayer {}

/// Метаданные и позиция из Music.app и Spotify.
///
/// Покрывает только эти два приложения — это цена пути B из ADR-0002. Для всего
/// остального `currentTrack()` честно возвращает `nil`, а не подставляет заглушку.
public struct ScriptingBridgeAdapter: NowPlayingReading, PlaybackSeeking {

  /// Приложение, у которого спрашиваем.
  public enum Player: Sendable {

    /// Music.app.
    case music

    /// Spotify.
    case spotify

    var bundleIdentifier: String {
      switch self {
      case .music: "com.apple.Music"
      case .spotify: "com.spotify.client"
      }
    }

    /// Имя для подписи источника в плеере.
    var title: String {
      switch self {
      case .music: "Music"
      case .spotify: "Spotify"
      }
    }

    /// Во сколько раз длительность отличается от секунд.
    ///
    /// Spotify отдаёт миллисекунды, Music.app — секунды. Разница не документирована
    /// в одном месте, поэтому вынесена сюда явно.
    var durationScale: Double {
      switch self {
      case .music: 1
      case .spotify: 1000
      }
    }
  }

  private let player: Player

  /// Создаёт адаптер.
  /// - Parameter player: приложение, у которого спрашивать.
  public init(player: Player) {
    self.player = player
  }

  /// Текущий трек.
  /// - Returns: трек или `nil`, если приложение не запущено или ничего не играет.
  public func currentTrack() async -> Track? {
    guard let application = running(), let track = application.currentTrack,
      let name = track.name, !name.isEmpty
    else { return nil }

    let duration = (track.duration ?? 0) / player.durationScale
    return Track(
      title: name,
      artist: track.artist ?? "",
      duration: duration > 0 ? duration : nil,
      source: player.title
    )
  }

  /// Текущая позиция воспроизведения.
  /// - Returns: позиция или `nil`, если приложение молчит.
  public func position() async -> PlaybackPosition? {
    guard let application = running(), let track = application.currentTrack,
      let elapsed = application.playerPosition
    else { return nil }

    let duration = (track.duration ?? 0) / player.durationScale
    guard duration > 0 else { return nil }
    return PlaybackPosition(elapsed: elapsed, duration: duration)
  }

  /// Перематывает трек.
  /// - Parameter elapsed: сколько должно быть сыграно после перемотки.
  public func seek(to elapsed: TimeInterval) async {
    running()?.setPlayerPosition?(elapsed)
  }

  private func running() -> ScriptablePlayer? {
    guard let application = SBApplication(bundleIdentifier: player.bundleIdentifier),
      application.isRunning
    else { return nil }
    return application
  }
}
