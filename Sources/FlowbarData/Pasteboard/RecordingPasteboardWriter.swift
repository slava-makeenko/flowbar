import FlowbarDomain
import Foundation

/// Пастборд, который помечает собственные записи приложения.
///
/// Обёртка, а не правка каждого места копирования: иначе про `noteOwnWrite` придётся
/// помнить в каждой вью-модели, и однажды кто-нибудь забудет — скопированное из истории
/// вернётся в историю же.
public struct RecordingPasteboardWriter: PasteboardWriting {

  private let pasteboard: any PasteboardWriting
  private let recorder: RecordPasteboardChange

  /// Создаёт обёртку.
  /// - Parameters:
  ///   - pasteboard: настоящий пастборд.
  ///   - recorder: юзкейс, ведущий историю копирований.
  public init(pasteboard: any PasteboardWriting, recorder: RecordPasteboardChange) {
    self.pasteboard = pasteboard
    self.recorder = recorder
  }

  /// Кладёт текст и помечает запись как собственную.
  /// - Parameter text: текст.
  public func write(text: String) async {
    await pasteboard.write(text: text)
    await recorder.noteOwnWrite()
  }

  /// Кладёт файл и помечает запись как собственную.
  /// - Parameters:
  ///   - fileURL: ссылка на файл.
  ///   - image: растр.
  public func write(fileURL: URL, image: Data) async {
    await pasteboard.write(fileURL: fileURL, image: image)
    await recorder.noteOwnWrite()
  }
}
