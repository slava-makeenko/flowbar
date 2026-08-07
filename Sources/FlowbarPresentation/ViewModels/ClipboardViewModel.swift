import FlowbarDomain
import Foundation

/// Экран истории копирований.
@MainActor
@Observable
public final class ClipboardViewModel {

  /// Записи истории, свежие первыми.
  public private(set) var clips: [ClipItem] = []

  private let store: any ClipStoring
  private let files: any FileReading
  private let pasteboard: any PasteboardWriting
  private let feedback: CopyFeedback

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - store: хранилище истории.
  ///   - files: чтение файлов для копий-картинок.
  ///   - pasteboard: запись в пастборд.
  ///   - feedback: подтверждение копирования.
  public init(
    store: any ClipStoring,
    files: any FileReading,
    pasteboard: any PasteboardWriting,
    feedback: CopyFeedback
  ) {
    self.store = store
    self.files = files
    self.pasteboard = pasteboard
    self.feedback = feedback
  }

  /// Идентификатор записи, чья кнопка копирования показывает галочку.
  public var confirmingItem: String? { feedback.confirmingItem }

  /// Читает историю из хранилища.
  public func load() async {
    clips = await store.all()
  }

  /// Подхватывает новые копии по мере их появления.
  /// - Parameter stream: поток записей от наблюдателя за пастбордом.
  public func observe(_ stream: AsyncStream<ClipItem>) async {
    for await clip in stream {
      clips.insert(clip, at: 0)
    }
  }

  /// Возвращает копию в пастборд.
  /// - Parameter clip: запись истории.
  public func copy(_ clip: ClipItem) async {
    switch clip.payload {
    case .string(let text):
      await pasteboard.write(text: text)
    case .imageFile(let url):
      guard let data = await files.data(at: url) else { return }
      await pasteboard.write(fileURL: url, image: data)
    }
    feedback.confirm("Скопировано в буфер", item: clip.id.uuidString)
  }

  /// Подпись под превью: вид, источник и время.
  /// - Parameter clip: запись истории.
  /// - Returns: строка вида «Notes · 2 минуты назад».
  public func caption(for clip: ClipItem) -> String {
    let moment = clip.capturedAt.formatted(
      .relative(presentation: .named).locale(InterfaceLocale.current)
    )
    return " · \(clip.sourceApp) · \(moment)"
  }
}
