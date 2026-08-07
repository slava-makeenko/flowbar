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

  /// Приложения, копии из которых не сохраняются даже без пометки конфиденциальности.
  ///
  /// Пометка `org.nspasteboard.ConcealedType` — конвенция, а не обязанность: менеджер
  /// паролей может её не выставить. Список — вторая линия обороны.
  public static let defaultBlockedBundleIdentifiers: Set<String> = [
    "com.1password.1password",
    "com.agilebits.onepassword7",
    "com.apple.keychainaccess",
    "com.bitwarden.desktop",
    "com.lastpass.LastPass",
    "in.sinew.Enpass-Desktop",
  ]

  private let pasteboard: any PasteboardReading
  private let clips: any ClipStoring
  private let blobs: any BlobStoring
  private let detector: ClipKindDetector
  private let clock: any Clock
  private let blockedBundleIdentifiers: Set<String>

  private var lastChangeCount: Int?
  private var hasSkippedContentFromBeforeLaunch = false

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

    // Первое замеченное изменение — это то, что лежало в пастборде ещё до запуска.
    // Счётчик запоминаем, но в историю не пишем: иначе каждый перезапуск добавлял бы
    // копию заново. Копия, сделанная в те доли секунды, пока приложение поднималось,
    // теряется — при автозапуске на входе в систему терять нечего.
    guard hasSkippedContentFromBeforeLaunch else {
      hasSkippedContentFromBeforeLaunch = true
      return nil
    }

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
    await promoteOrSave(clip)
    return clip
  }

  /// Сохраняет запись, подняв наверх такую же, если она уже есть.
  ///
  /// Повторное копирование того же текста не плодит строки: старая запись удаляется,
  /// новая встаёт наверх со свежим временем. Именно со свежим — иначе ежедневно
  /// используемая копия сохранила бы первоначальную дату и однажды была бы удалена
  /// чисткой как просроченная.
  ///
  /// Картинки не сравниваются: у каждой свой файл, и совпадение содержимого пришлось бы
  /// проверять чтением с диска на каждое копирование.
  private func promoteOrSave(_ clip: ClipItem) async {
    if case .string(let text) = clip.payload {
      let existing = await clips.all()
      let duplicates = existing.filter { $0.payload == .string(text) }
      if !duplicates.isEmpty {
        await clips.remove(ids: duplicates.map(\.id))
      }
    }
    await clips.save(clip)
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
