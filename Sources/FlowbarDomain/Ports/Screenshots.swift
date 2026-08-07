import Foundation

/// Источник последних снимков экрана.
public protocol ScreenshotSourcing: Sendable {

  /// Поток списков снимков, свежие первыми.
  ///
  /// Новое значение приходит при каждом изменении папки со снимками — приложение не хранит
  /// файлы, а читает файловую систему.
  var screenshots: AsyncStream<[Screenshot]> { get }
}

/// Построение превью для файла.
public protocol ThumbnailRendering: Sendable {

  /// Строит превью снимка.
  /// - Parameters:
  ///   - url: путь к файлу.
  ///   - size: желаемый размер превью в пикселях.
  /// - Returns: растр превью или `nil`, если построить не удалось.
  func thumbnail(for url: URL, size: PixelSize) async -> Data?
}

/// Чтение содержимого файла.
///
/// Порта нет в регламенте §3, но без него `CopyScreenshot` вырождается: класть в пастборд
/// два представления — это решение домена, а прочитать растр домен сам не может.
public protocol FileReading: Sendable {

  /// Читает файл целиком.
  /// - Parameter url: путь к файлу.
  /// - Returns: содержимое или `nil`, если прочитать не удалось.
  func data(at url: URL) async -> Data?
}

/// Удаление файла в Корзину.
///
/// Именно в Корзину: пользователь удаляет свой файл, который приложение не создавало.
public protocol FileTrashing: Sendable {

  /// Перемещает файл в Корзину.
  /// - Parameter url: путь к файлу.
  /// - Returns: `true`, если файл перемещён.
  func trash(_ url: URL) async -> Bool
}
