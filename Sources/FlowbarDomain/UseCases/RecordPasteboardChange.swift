import Foundation

/// Записывает очередное изменение пастборда в историю.
///
/// Тип заведён потому, что внутри есть решение — сохранять ли вообще, — классификация и
/// запись в два порта. Регламент §4.
public actor RecordPasteboardChange {

  /// Максимальная длина превью.
  ///
  /// Превью попадает в базу, а скопировать могут мегабайт текста. Визуальное обрезание
  /// многоточием — забота вьюхи, здесь только предел хранимого.
  public static let previewLimit = 300

  private let pasteboard: any PasteboardReading
  private let clips: any ClipStoring
  private let blobs: any BlobStoring
  private let detector: ClipKindDetector
  private let clock: any Clock
  private let blockedBundleIdentifiers: Set<String>

  private var lastChangeCount: Int?

  /// Создаёт юзкейс.
  /// - Parameters:
  ///   - pasteboard: чтение пастборда.
  ///   - clips: хранилище истории.
  ///   - blobs: хранилище растров.
  ///   - detector: определитель вида копии.
  ///   - clock: источник времени.
  ///   - blockedBundleIdentifiers: приложения, копии из которых не сохраняются.
  public init(
    pasteboard: any PasteboardReading,
    clips: any ClipStoring,
    blobs: any BlobStoring,
    detector: ClipKindDetector = ClipKindDetector(),
    clock: any Clock,
    blockedBundleIdentifiers: Set<String> = []
  ) {
    self.pasteboard = pasteboard
    self.clips = clips
    self.blobs = blobs
    self.detector = detector
    self.clock = clock
    self.blockedBundleIdentifiers = blockedBundleIdentifiers
  }

  /// Сообщает, что в пастборд записало само приложение.
  ///
  /// Ближайший опрос увидит счётчик, который здесь запомнен, и ничего не сохранит.
  /// Без этого копирование из истории возвращало бы копию обратно в историю.
  public func noteOwnWrite() async {
    lastChangeCount = await pasteboard.changeCount
  }

  /// Считывает пастборд и сохраняет запись, если её следует сохранять.
  /// - Returns: сохранённая запись или `nil`, если сохранять нечего.
  @discardableResult
  public func callAsFunction() async -> ClipItem? {
    let changeCount = await pasteboard.changeCount
    guard changeCount != lastChangeCount else { return nil }
    lastChangeCount = changeCount

    guard let item = await pasteboard.read() else { return nil }
    guard !item.isConcealed, !item.isTransient else { return nil }
    if let bundle = item.sourceApp.bundleIdentifier, blockedBundleIdentifiers.contains(bundle) {
      return nil
    }

    let identifier = UUID()
    guard let payload = await payload(for: item, id: identifier) else { return nil }

    let clip = ClipItem(
      id: identifier,
      kind: detector.detect(item),
      preview: Self.preview(for: item),
      payload: payload,
      sourceApp: item.sourceApp.name,
      capturedAt: clock.now
    )
    await clips.save(clip)
    return clip
  }

  // MARK: - Разбор содержимого

  private func payload(for item: PasteboardItem, id: UUID) async -> ClipPayload? {
    if let data = item.imageData {
      guard let url = await blobs.store(data, for: id) else { return nil }
      return .imageFile(url)
    }
    if let url = item.fileURL {
      return .string(url.path)
    }
    if let text = item.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return .string(text)
    }
    return nil
  }

  private static func preview(for item: PasteboardItem) -> String {
    let source = item.text ?? item.fileURL?.path ?? ""
    let singleLine =
      source
      .split(whereSeparator: \.isNewline)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespaces)
    return String(singleLine.prefix(previewLimit))
  }
}
