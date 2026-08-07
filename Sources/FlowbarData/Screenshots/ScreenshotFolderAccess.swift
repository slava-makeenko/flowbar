import AppKit
import FlowbarDomain
import Foundation

/// Доступ к папке со снимками экрана.
///
/// Под песочницей приложение не может читать `~/Desktop` само: пользователь выбирает папку
/// один раз, а дальше доступ живёт в security-scoped bookmark. ADR-0003.
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

  /// Восстанавливает доступ по сохранённой закладке.
  /// - Returns: папка или `nil`, если закладки нет или она устарела.
  public func currentFolder() -> URL? {
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
