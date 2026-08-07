import Foundation

/// Трек, играющий в системе.
public struct Track: Equatable, Sendable {

  /// Название трека.
  public let title: String

  /// Исполнитель.
  public let artist: String

  /// Обложка в виде растра, если источник её отдаёт.
  public let artwork: Data?

  /// Длительность, если источник её отдаёт.
  public let duration: TimeInterval?

  /// Имя приложения-источника: «Music», «Spotify».
  public let source: String

  /// Создаёт описание трека.
  /// - Parameters:
  ///   - title: название.
  ///   - artist: исполнитель.
  ///   - artwork: обложка.
  ///   - duration: длительность.
  ///   - source: имя приложения-источника.
  public init(
    title: String,
    artist: String,
    artwork: Data? = nil,
    duration: TimeInterval? = nil,
    source: String
  ) {
    self.title = title
    self.artist = artist
    self.artwork = artwork
    self.duration = duration
    self.source = source
  }
}

/// Позиция воспроизведения внутри трека.
public struct PlaybackPosition: Equatable, Sendable {

  /// Сколько уже сыграно.
  public let elapsed: TimeInterval

  /// Полная длительность трека.
  public let duration: TimeInterval

  /// Создаёт позицию воспроизведения.
  /// - Parameters:
  ///   - elapsed: сколько сыграно.
  ///   - duration: полная длительность.
  public init(elapsed: TimeInterval, duration: TimeInterval) {
    self.elapsed = elapsed
    self.duration = duration
  }
}
