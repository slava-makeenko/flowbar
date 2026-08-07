import Foundation

/// Кладёт снимок экрана в пастборд.
///
/// Тип заведён ради решения: в пастборд идут **два** представления сразу — ссылка на файл
/// и растр. Finder и почтовые клиенты берут первое, редакторы изображений второе.
/// Половинчатая запись хуже отказа, поэтому без растра не пишется ничего.
public struct CopyScreenshot: Sendable {

  private let files: any FileReading
  private let pasteboard: any PasteboardWriting

  /// Создаёт юзкейс.
  /// - Parameters:
  ///   - files: чтение файлов.
  ///   - pasteboard: запись в пастборд.
  public init(files: any FileReading, pasteboard: any PasteboardWriting) {
    self.files = files
    self.pasteboard = pasteboard
  }

  /// Копирует снимок в пастборд.
  /// - Parameter screenshot: снимок экрана.
  /// - Returns: `true`, если оба представления записаны.
  @discardableResult
  public func callAsFunction(_ screenshot: Screenshot) async -> Bool {
    guard let data = await files.data(at: screenshot.id) else { return false }
    await pasteboard.write(fileURL: screenshot.id, image: data)
    return true
  }
}
