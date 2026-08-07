import FlowbarDomain
import Foundation

/// Источник, опрашивающий несколько поставщиков метаданных по очереди.
///
/// Здесь архитектура окупается буквально: когда Apple в очередной раз что-то закроет,
/// меняется один адаптер, а домен, представление и вьюхи не трогаются.
public struct CompositeNowPlayingSource: NowPlayingReading, PlaybackControlling, PlaybackSeeking {

  private let metadataSources: [any NowPlayingReading]
  private let seekingSources: [any PlaybackSeeking]
  private let controller: any PlaybackControlling

  /// Создаёт композит.
  /// - Parameters:
  ///   - metadataSources: поставщики метаданных в порядке опроса.
  ///   - seekingSources: поставщики позиции в порядке опроса.
  ///   - controller: управление воспроизведением; работает всегда.
  public init(
    metadataSources: [any NowPlayingReading],
    seekingSources: [any PlaybackSeeking],
    controller: any PlaybackControlling
  ) {
    self.metadataSources = metadataSources
    self.seekingSources = seekingSources
    self.controller = controller
  }

  /// Первый источник, который отдал трек.
  /// - Returns: трек или `nil`, если метаданных нет ни у кого.
  public func currentTrack() async -> Track? {
    for source in metadataSources {
      if let track = await source.currentTrack() { return track }
    }
    return nil
  }

  /// Первый источник, который отдал позицию.
  /// - Returns: позиция или `nil`, если её не знает никто.
  public func position() async -> PlaybackPosition? {
    for source in seekingSources {
      if let position = await source.position() { return position }
    }
    return nil
  }

  /// Перематывает трек у всех источников, которые это умеют.
  /// - Parameter elapsed: сколько должно быть сыграно после перемотки.
  public func seek(to elapsed: TimeInterval) async {
    for source in seekingSources {
      await source.seek(to: elapsed)
    }
  }

  /// Переключает воспроизведение и паузу.
  public func toggle() async {
    await controller.toggle()
  }

  /// Переходит к следующему треку.
  public func next() async {
    await controller.next()
  }

  /// Переходит к предыдущему треку.
  public func previous() async {
    await controller.previous()
  }
}
