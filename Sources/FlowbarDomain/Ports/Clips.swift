import Foundation

/// Хранилище истории копирований.
public protocol ClipStoring: Sendable {

  /// Сохраняет запись.
  /// - Parameter item: запись истории.
  func save(_ item: ClipItem) async

  /// Все записи, свежие первыми.
  func all() async -> [ClipItem]

  /// Записи, попавшие в историю раньше указанного момента.
  /// - Parameter date: граница отбора; сам момент в выборку не входит.
  /// - Returns: просроченные записи.
  func items(capturedBefore date: Date) async -> [ClipItem]

  /// Удаляет записи по идентификаторам.
  /// - Parameter ids: идентификаторы записей.
  func remove(ids: [UUID]) async
}

/// Хранилище файлов изображений из истории.
///
/// Отдельный порт, а не часть `ClipStoring`: метаданные живут в базе, а картинки — файлами
/// на диске, и эти два хранилища меняются по разным причинам.
public protocol BlobStoring: Sendable {

  /// Сохраняет растр и возвращает путь к нему.
  /// - Parameters:
  ///   - data: растр.
  ///   - id: идентификатор записи, к которой относится файл.
  /// - Returns: путь к сохранённому файлу или `nil`, если записать не удалось.
  func store(_ data: Data, for id: UUID) async -> URL?

  /// Удаляет файл.
  /// - Parameter url: путь к файлу.
  func remove(at url: URL) async
}
