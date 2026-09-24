import AppKit
import FlowbarDomain
import Foundation

/// Доступ к папке со снимками экрана.
///
/// Папку, выбранную пользователем, помнит закладка. Без неё берётся системная папка
/// снимков: песочницы нет, и читать её напрямую можно. ADR-0016.
@MainActor
public final class ScreenshotFolderAccess: ScreenshotFolderAccessing {

  private static let bookmarkKey = "screenshotFolderBookmark"

  private let defaults: UserDefaults
  private var accessedFolder: URL?

  /// Создаёт доступ.
  /// - Parameter defaults: хранилище закладки.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// Папка, куда система кладёт снимки.
  ///
  /// Читается из настроек `screencapture`; если пользователь её не менял — рабочий стол.
  public static var systemLocation: URL {
    let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
    if let configured, !configured.isEmpty {
      return URL(fileURLWithPath: (configured as NSString).expandingTildeInPath)
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appending(path: "Desktop")
  }

  /// Папка, выбранная пользователем, а без выбора — системная папка снимков.
  ///
  /// Закладки, созданные под песочницей, вне её не открываются (ошибка 259) — такая
  /// закладка тоже ведёт к системной папке, а не к повторному вопросу.
  /// - Returns: папка или `nil`, если нет ни закладки, ни системной папки.
  public func currentFolder() -> URL? {
    if let chosen = chosenFolder() { return chosen }
    let system = Self.systemLocation
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: system.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue ? system : nil
  }

  /// Восстанавливает доступ по сохранённой закладке.
  private func chosenFolder() -> URL? {
    guard let data = defaults.data(forKey: Self.bookmarkKey) else { return nil }

    var isStale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        bookmarkDataIsStale: &isStale
      ), url.startAccessingSecurityScopedResource()
    else { return nil }

    accessedFolder = url
    if isStale { save(url) }
    return url
  }

  /// Показывает системный выбор папки.
  ///
  /// Приложение резидентное и не активно, поэтому его приходится вывести вперёд —
  /// иначе панель выбора откроется за чужим окном.
  /// - Returns: выбранная папка или `nil`, если пользователь отказался.
  public func requestFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = Self.systemLocation
    panel.prompt = "Разрешить"
    panel.message = "Выберите папку со снимками экрана, чтобы Flowbar мог их показывать."

    NSApp.activate()
    guard panel.runModal() == .OK, let url = panel.url else { return nil }

    save(url)
    _ = url.startAccessingSecurityScopedResource()
    accessedFolder = url
    return url
  }

  /// Отпускает доступ к папке.
  public func release() {
    accessedFolder?.stopAccessingSecurityScopedResource()
    accessedFolder = nil
  }

  private func save(_ url: URL) {
    let data = try? url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    defaults.set(data, forKey: Self.bookmarkKey)
  }
}
