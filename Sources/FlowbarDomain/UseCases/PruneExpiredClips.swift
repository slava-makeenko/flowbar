import Foundation

/// Чистит историю от записей старше срока жизни.
///
/// Тип заведён ради инварианта «семь дней» и согласованного удаления: запись и её растр
/// исчезают вместе, иначе на диске остаются файлы, на которые никто не ссылается.
public struct PruneExpiredClips: Sendable {

  /// Срок жизни записи в истории — семь суток.
  public static let defaultLifetime: TimeInterval = 7 * 24 * 60 * 60

  private let clips: any ClipStoring
  private let blobs: any BlobStoring
  private let clock: any Clock
  private let lifetime: TimeInterval

  /// Создаёт юзкейс.
  /// - Parameters:
  ///   - clips: хранилище истории.
  ///   - blobs: хранилище растров.
  ///   - clock: источник времени.
  ///   - lifetime: срок жизни записи.
  public init(
    clips: any ClipStoring,
    blobs: any BlobStoring,
    clock: any Clock,
    lifetime: TimeInterval = PruneExpiredClips.defaultLifetime
  ) {
    self.clips = clips
    self.blobs = blobs
    self.clock = clock
    self.lifetime = lifetime
  }

  /// Удаляет просроченные записи вместе с их файлами.
  /// - Returns: сколько записей удалено.
  @discardableResult
  public func callAsFunction() async -> Int {
    let deadline = clock.now.addingTimeInterval(-lifetime)
    let expired = await clips.items(capturedBefore: deadline)
    guard !expired.isEmpty else { return 0 }

    for item in expired {
      if case .imageFile(let url) = item.payload {
        await blobs.remove(at: url)
      }
    }
    await clips.remove(ids: expired.map(\.id))
    return expired.count
  }
}
