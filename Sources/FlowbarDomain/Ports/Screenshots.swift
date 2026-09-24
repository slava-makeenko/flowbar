import Foundation

/// Источник последних снимков экрана.
public protocol ScreenshotSourcing: Sendable {

  /// Поток списков снимков, свежие первыми.
  ///
  /// Новое значение приходит при каждом изменении папки со снимками — приложение не хранит
  /// файлы, а читает файловую систему.
  var screenshots: AsyncStream<[Screenshot]> { get }

  /// Начинает наблюдение за папкой.
  /// - Parameter folder: папка со снимками.
  func start(in folder: URL) async
}

/// Доступ к папке со снимками.
///
/// Отдельный порт, потому что папка — выбор пользователя: его нужно помнить и уметь
/// поменять. Без выбора берётся системная папка снимков. ADR-0016.
public protocol ScreenshotFolderAccessing: Sendable {

  /// Папка, доступ к которой уже есть.
  /// - Returns: папка или `nil`, если разрешения ещё нет.
  func currentFolder() async -> URL?

  /// Просит пользователя выбрать папку.
  /// - Returns: выбранная папка или `nil`, если пользователь отказался.
  func requestFolder() async -> URL?
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
