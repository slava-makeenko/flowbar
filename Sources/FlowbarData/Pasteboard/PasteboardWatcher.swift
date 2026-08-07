import FlowbarDomain
import Foundation

/// Опрашивает пастборд с постоянным шагом.
///
/// Уведомлений об изменении пастборда в macOS нет, поэтому единственный способ заметить
/// копирование — периодически сравнивать счётчик изменений. Отдельный тип, потому что
/// меняться будет по своей причине: частота опроса и условия паузы.
public actor PasteboardWatcher {

  /// Шаг опроса по умолчанию.
  public static let defaultInterval: Duration = .milliseconds(300)

  /// Поток новых записей истории.
  ///
  /// Опрос живёт в акторе, а наружу отдаёт через поток — регламент §7.
  public nonisolated let recordedClips: AsyncStream<ClipItem>

  private let record: RecordPasteboardChange
  private let interval: Duration
  private let continuation: AsyncStream<ClipItem>.Continuation
  private var loop: Task<Void, Never>?

  /// Создаёт наблюдатель.
  /// - Parameters:
  ///   - record: юзкейс записи изменения в историю.
  ///   - interval: шаг опроса.
  public init(
    record: RecordPasteboardChange, interval: Duration = PasteboardWatcher.defaultInterval
  ) {
    self.record = record
    self.interval = interval
    (recordedClips, continuation) = AsyncStream.makeStream()
  }

  /// Запускает опрос. Повторный вызов ничего не меняет.
  public func start() {
    guard loop == nil else { return }
    loop = Task { [record, interval, continuation] in
      while !Task.isCancelled {
        if let clip = await record() { continuation.yield(clip) }
        try? await Task.sleep(for: interval)
      }
    }
  }

  /// Останавливает опрос.
  public func stop() {
    loop?.cancel()
    loop = nil
  }
}
