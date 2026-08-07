import FlowbarDomain
import Foundation

/// Экран ленты снимков.
@MainActor
@Observable
public final class ScreenshotsViewModel {

  /// Размер превью карточки в пикселях.
  public static let thumbnailSize = PixelSize(width: 448, height: 252)

  /// Состояние доступа к папке со снимками.
  public enum Access: Equatable, Sendable {

    /// Разрешение ещё не получено.
    case needed

    /// Папка доступна.
    case granted
  }

  /// Текущее состояние доступа.
  public private(set) var access: Access = .needed

  /// Снимки, свежие первыми.
  public private(set) var screenshots: [Screenshot] = []

  /// Готовые превью по путям файлов.
  public private(set) var thumbnails: [URL: Data] = [:]

  private let folderAccess: any ScreenshotFolderAccessing
  private let source: any ScreenshotSourcing
  private let renderer: any ThumbnailRendering
  private let copyScreenshot: CopyScreenshot
  private let trash: any FileTrashing
  private let feedback: CopyFeedback

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - folderAccess: доступ к папке со снимками.
  ///   - source: источник ленты.
  ///   - renderer: построение превью.
  ///   - copyScreenshot: копирование снимка в пастборд.
  ///   - trash: удаление в Корзину.
  ///   - feedback: подтверждение копирования.
  public init(
    folderAccess: any ScreenshotFolderAccessing,
    source: any ScreenshotSourcing,
    renderer: any ThumbnailRendering,
    copyScreenshot: CopyScreenshot,
    trash: any FileTrashing,
    feedback: CopyFeedback
  ) {
    self.folderAccess = folderAccess
    self.source = source
    self.renderer = renderer
    self.copyScreenshot = copyScreenshot
    self.trash = trash
    self.feedback = feedback
  }

  /// Путь снимка, чья карточка сейчас подтверждена рамкой.
  public var confirmedItem: String? { feedback.confirmingItem }

  /// Восстанавливает доступ и запускает ленту, если разрешение уже есть.
  public func start() async {
    guard let folder = await folderAccess.currentFolder() else { return }
    await begin(in: folder)
  }

  /// Просит пользователя выбрать папку и запускает ленту.
  public func requestAccess() async {
    guard let folder = await folderAccess.requestFolder() else { return }
    await begin(in: folder)
  }

  /// Кладёт снимок в пастборд.
  /// - Parameter screenshot: снимок.
  public func copy(_ screenshot: Screenshot) async {
    guard await copyScreenshot(screenshot) else { return }
    feedback.confirm(
      "Снимок скопирован",
      item: screenshot.id.path,
      duration: CopyFeedback.cardConfirmationDuration
    )
  }

  /// Удаляет снимок в Корзину.
  /// - Parameter screenshot: снимок.
  public func delete(_ screenshot: Screenshot) async {
    guard await trash.trash(screenshot.id) else { return }
    screenshots.removeAll { $0.id == screenshot.id }
    thumbnails[screenshot.id] = nil
  }

  /// Подпись под именем файла: размеры и вес.
  /// - Parameter screenshot: снимок.
  /// - Returns: строка вида «1244 × 806 · 248 КБ».
  public func caption(for screenshot: Screenshot) -> String {
    let size = screenshot.byteSize.formatted(
      .byteCount(style: .file).locale(InterfaceLocale.current)
    )
    return "\(screenshot.pixelSize.width) × \(screenshot.pixelSize.height) · \(size)"
  }

  /// Время создания снимка относительно текущего момента.
  /// - Parameter screenshot: снимок.
  /// - Returns: строка вида «2 минуты назад».
  public func moment(for screenshot: Screenshot) -> String {
    screenshot.createdAt.formatted(
      .relative(presentation: .named).locale(InterfaceLocale.current)
    )
  }

  // MARK: - Лента

  private func begin(in folder: URL) async {
    access = .granted
    await source.start(in: folder)
    Task { await observe() }
  }

  private func observe() async {
    for await batch in source.screenshots {
      screenshots = batch
      await loadThumbnails(for: batch)
    }
  }

  private func loadThumbnails(for batch: [Screenshot]) async {
    for screenshot in batch where thumbnails[screenshot.id] == nil {
      thumbnails[screenshot.id] = await renderer.thumbnail(
        for: screenshot.id,
        size: Self.thumbnailSize
      )
    }
  }
}
