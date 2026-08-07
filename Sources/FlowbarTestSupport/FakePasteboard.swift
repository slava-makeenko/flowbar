import FlowbarDomain
import Foundation

/// Запись, сделанная в пастборд.
public enum PasteboardWrite: Equatable, Sendable {

  /// Записан текст.
  case text(String)

  /// Записан файл двумя представлениями.
  case file(url: URL, image: Data)
}

/// Пастборд-фейк: помнит содержимое, счётчик изменений и все записи.
public actor FakePasteboard: PasteboardReading, PasteboardWriting {

  /// Всё, что приложение записало в пастборд, в порядке записи.
  public private(set) var writes: [PasteboardWrite] = []

  private static let ownApp = SourceApp(name: "Flowbar", bundleIdentifier: "app.flowbar.Flowbar")

  private var contents: PasteboardItem?
  private var counter = 0

  /// Создаёт пустой пастборд.
  public init() {}

  /// Счётчик изменений: растёт и от `copy(_:)`, и от записей приложения.
  public var changeCount: Int { counter }

  /// Текущее содержимое.
  /// - Returns: содержимое или `nil`, если пастборд пуст.
  public func read() -> PasteboardItem? { contents }

  /// Записывает текст и делает его текущим содержимым.
  /// - Parameter text: текст.
  public func write(text: String) {
    writes.append(.text(text))
    // Настоящий пастборд после записи отдаёт то, что в него положили, — иначе проверка
    // «собственная запись не возвращается в историю» была бы пустой.
    contents = PasteboardItem(text: text, sourceApp: Self.ownApp)
    counter += 1
  }

  /// Записывает файл двумя представлениями и делает его текущим содержимым.
  /// - Parameters:
  ///   - fileURL: ссылка на файл.
  ///   - image: растр.
  public func write(fileURL: URL, image: Data) {
    writes.append(.file(url: fileURL, image: image))
    contents = PasteboardItem(fileURL: fileURL, imageData: image, sourceApp: Self.ownApp)
    counter += 1
  }

  /// Имитирует копирование пользователем: подменяет содержимое и двигает счётчик.
  /// - Parameter item: новое содержимое пастборда.
  public func copy(_ item: PasteboardItem) {
    contents = item
    counter += 1
  }
}
