import Foundation

/// Чтение пастборда.
///
/// Уведомлений об изменении пастборда в macOS нет, поэтому единственный способ заметить
/// копирование — сравнивать счётчик изменений. Частота опроса — забота адаптера.
public protocol PasteboardReading: Sendable {

  /// Счётчик изменений пастборда. Растёт при каждой записи, кем бы она ни была сделана.
  var changeCount: Int { get async }

  /// Текущее содержимое пастборда.
  /// - Returns: снимок содержимого или `nil`, если пастборд пуст.
  func read() async -> PasteboardItem?
}

/// Запись в пастборд.
public protocol PasteboardWriting: Sendable {

  /// Кладёт текст в пастборд.
  /// - Parameter text: текст.
  func write(text: String) async

  /// Кладёт файл двумя представлениями сразу: ссылкой и растром.
  ///
  /// Оба обязательны: Finder и почтовые клиенты берут ссылку, редакторы изображений — растр.
  /// - Parameters:
  ///   - fileURL: ссылка на файл.
  ///   - image: растр того же файла.
  func write(fileURL: URL, image: Data) async
}
