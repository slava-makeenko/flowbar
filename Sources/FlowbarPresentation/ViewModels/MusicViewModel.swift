import FlowbarDomain
import Foundation

/// Экран плеера.
@MainActor
@Observable
public final class MusicViewModel {

  /// Как часто обновляются метаданные и позиция.
  public static let refreshInterval: Duration = .seconds(1)

  /// Играющий трек; `nil` — метаданных нет.
  public private(set) var track: Track?

  /// Позиция внутри трека; `nil` — источник её не отдаёт.
  ///
  /// Когда позиции нет, полосу прогресса нужно **скрывать**, а не показывать нулевой:
  /// нулевой прогресс — это утверждение, которого мы не знаем.
  public private(set) var position: PlaybackPosition?

  /// Имя устройства вывода.
  public private(set) var outputDevice: String?

  /// Системная громкость от 0 до 1.
  public var volume: Double = 0 {
    didSet {
      guard abs(volume - oldValue) > 0.001 else { return }
      Task { await volumeControl.setVolume(volume) }
    }
  }

  private let nowPlaying: any NowPlayingReading
  private let playback: any PlaybackControlling
  private let seeking: any PlaybackSeeking
  private let volumeControl: any SystemVolumeControlling

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - nowPlaying: метаданные трека.
  ///   - playback: управление воспроизведением.
  ///   - seeking: позиция внутри трека.
  ///   - volumeControl: системная громкость.
  public init(
    nowPlaying: any NowPlayingReading,
    playback: any PlaybackControlling,
    seeking: any PlaybackSeeking,
    volumeControl: any SystemVolumeControlling
  ) {
    self.nowPlaying = nowPlaying
    self.playback = playback
    self.seeking = seeking
    self.volumeControl = volumeControl
  }

  /// Обновляет состояние раз в секунду, пока задача не отменена.
  public func observe() async {
    volume = await volumeControl.volume
    outputDevice = await volumeControl.outputDeviceName()

    while !Task.isCancelled {
      track = await nowPlaying.currentTrack()
      position = await seeking.position()
      try? await Task.sleep(for: Self.refreshInterval)
    }
  }

  /// Переключает воспроизведение и паузу.
  public func toggle() async {
    await playback.toggle()
  }

  /// Следующий трек.
  public func next() async {
    await playback.next()
  }

  /// Предыдущий трек.
  public func previous() async {
    await playback.previous()
  }

  /// Перематывает трек.
  /// - Parameter fraction: доля от начала трека, от 0 до 1.
  public func seek(toFraction fraction: Double) async {
    guard let position else { return }
    await seeking.seek(to: position.duration * min(max(fraction, 0), 1))
  }

  /// Подпись источника метаданных.
  public var sourceTitle: String {
    track?.source ?? "Источник без метаданных"
  }

  /// Время в формате `м:сс`.
  /// - Parameter seconds: секунды.
  /// - Returns: строка вида «3:07».
  public nonisolated static func time(_ seconds: TimeInterval) -> String {
    let total = Int(max(seconds, 0))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}
