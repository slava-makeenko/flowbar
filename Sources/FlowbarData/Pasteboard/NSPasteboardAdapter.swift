import AppKit
import FlowbarDomain

/// Чтение и запись системного пастборда.
///
/// `NSPasteboard.general` и `NSWorkspace.shared` живут только здесь и наружу не протекают.
@MainActor
public struct NSPasteboardAdapter: PasteboardReading, PasteboardWriting {

  /// Пометка менеджеров паролей: содержимое не должно попадать в истории копирований.
  private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

  /// Пометка временного содержимого по конвенции nspasteboard.org.
  private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

  /// Создаёт адаптер.
  public init() {}

  /// Счётчик изменений пастборда.
  public var changeCount: Int { NSPasteboard.general.changeCount }

  /// Читает текущее содержимое пастборда.
  /// - Returns: снимок содержимого или `nil`, если пастборд пуст.
  public func read() -> PasteboardItem? {
    let pasteboard = NSPasteboard.general
    let types = Set(pasteboard.types ?? [])

    let fileURL = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL])?
      .first { $0.isFileURL }
    let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
    let text = pasteboard.string(forType: .string)

    guard text != nil || fileURL != nil || imageData != nil else { return nil }

    return PasteboardItem(
      text: text,
      fileURL: fileURL,
      imageData: imageData,
      isConcealed: types.contains(Self.concealed),
      isTransient: types.contains(Self.transient),
      sourceApp: frontmostApp()
    )
  }

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

  private func frontmostApp() -> SourceApp {
    let app = NSWorkspace.shared.frontmostApplication
    return SourceApp(
      name: app?.localizedName ?? "Неизвестно",
      bundleIdentifier: app?.bundleIdentifier
    )
  }
}
