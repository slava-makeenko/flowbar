import AppKit
import FlowbarDomain

/// Запись в системный пастборд.
///
/// `NSPasteboard.general` живёт только здесь и наружу не протекает.
public struct NSPasteboardAdapter: PasteboardWriting {

  /// Создаёт адаптер.
  public init() {}

  /// Кладёт текст в пастборд.
  /// - Parameter text: текст.
  public func write(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  /// Кладёт файл ссылкой и растром сразу.
  /// - Parameters:
  ///   - fileURL: ссылка на файл.
  ///   - image: растр того же файла.
  public func write(fileURL: URL, image: Data) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([fileURL as NSURL])
    pasteboard.setData(image, forType: .png)
  }
}
