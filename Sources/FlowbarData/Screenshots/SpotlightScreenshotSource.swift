import FlowbarDomain
import Foundation

/// Лента последних снимков экрана из Spotlight.
///
/// Атрибут `kMDItemIsScreenCapture` выставляет сама утилита `screencapture`, поэтому
/// запрос не поймает посторонние png, лежащие в той же папке, — в отличие от слежения
/// за расширением файла.
@MainActor
public final class SpotlightScreenshotSource: ScreenshotSourcing {

  /// Сколько снимков показывается в ленте.
  public static let limit = 30

  /// Поток списков снимков, свежие первыми.
  public nonisolated let screenshots: AsyncStream<[Screenshot]>

  private let continuation: AsyncStream<[Screenshot]>.Continuation
  private let query = NSMetadataQuery()
  private var observers: [NSObjectProtocol] = []

  /// Создаёт источник.
  public init() {
    (screenshots, continuation) = AsyncStream.makeStream()
  }

  /// Запускает наблюдение за папкой.
  /// - Parameter folder: папка со снимками.
  public func start(in folder: URL) {
    stop()

    query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
    query.searchScopes = [folder]
    query.sortDescriptors = [
      NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)
    ]

    for name in [
      NSNotification.Name.NSMetadataQueryDidFinishGathering,
      NSNotification.Name.NSMetadataQueryDidUpdate,
    ] {
      let observer = NotificationCenter.default.addObserver(
        forName: name,
        object: query,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.publish() }
      }
      observers.append(observer)
    }

    query.start()
  }

  /// Останавливает наблюдение.
  public func stop() {
    query.stop()
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
  }

  private func publish() {
    query.disableUpdates()
    defer { query.enableUpdates() }

    let items = (0..<query.resultCount)
      .compactMap { query.result(at: $0) as? NSMetadataItem }
      .compactMap(Self.screenshot)
      .prefix(Self.limit)

    continuation.yield(Array(items))
  }

  private static func screenshot(from item: NSMetadataItem) -> Screenshot? {
    // Путь, а не `kMDItemURL`: этого атрибута в выдаче Spotlight попросту нет —
    // проверено на macOS 26.5, запрос возвращал элементы, но ссылка у всех была `nil`.
    guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
      let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
      let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date
    else { return nil }

    let url = URL(fileURLWithPath: path)

    let width = item.value(forAttribute: "kMDItemPixelWidth") as? Int ?? 0
    let height = item.value(forAttribute: "kMDItemPixelHeight") as? Int ?? 0
    let bytes = item.value(forAttribute: NSMetadataItemFSSizeKey) as? Int ?? 0

    return Screenshot(
      id: url,
      name: name,
      pixelSize: PixelSize(width: width, height: height),
      byteSize: bytes,
      createdAt: created
    )
  }
}
