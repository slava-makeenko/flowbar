import AppKit
import FlowbarDomain
import Foundation

/// Доступ к папкам агентов через security-scoped bookmark. ADR-0012.
///
/// Устроен как `ScreenshotFolderAccess`, но закладок две — по одной на агента.
@MainActor
public final class AgentFolderAccess: AgentFolderAccessing {

  private let defaults: UserDefaults
  private var accessedFolders: [Agent: URL] = [:]

  /// Создаёт доступ.
  /// - Parameter defaults: хранилище закладок.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  /// Папка агента в настоящем домашнем каталоге.
  ///
  /// Не `homeDirectoryForCurrentUser`: под песочницей он указывает внутрь контейнера,
  /// а агенты живут в домашней папке пользователя.
  /// - Parameter agent: агент.
  /// - Returns: `~/.claude` или `~/.codex`.
  public static func expectedLocation(of agent: Agent) -> URL {
    let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) }
    let base = URL(filePath: home ?? NSHomeDirectory(), directoryHint: .isDirectory)
    return base.appending(path: folderName(of: agent), directoryHint: .isDirectory)
  }

  /// Восстанавливает доступ по сохранённой закладке.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если закладки нет или она устарела.
  public func currentFolder(for agent: Agent) -> URL? {
    if let folder = accessedFolders[agent] { return folder }
    guard let data = defaults.data(forKey: Self.bookmarkKey(for: agent)) else { return nil }

    var isStale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        bookmarkDataIsStale: &isStale
      ), url.startAccessingSecurityScopedResource()
    else { return nil }

    accessedFolders[agent] = url
    if isStale { save(url, for: agent) }
    return url
  }

  /// Показывает системный выбор папки, открытый внутри нужной.
  ///
  /// Панель открывается в самой папке агента, а не в домашней: «Разрешить» выбирает
  /// текущий каталог, и из домашней панель вернула бы домашнюю. Папки скрытые, поэтому
  /// панель показывает скрытые файлы. Выбор чужой папки не сохраняется: иначе приложение
  /// запомнило бы бесполезную закладку и больше не спросило.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если пользователь отказался или выбрал не ту.
  public func requestFolder(for agent: Agent) -> URL? {
    let expected = Self.expectedLocation(of: agent)
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.showsHiddenFiles = true
    panel.directoryURL = expected
    panel.prompt = "Разрешить"
    panel.message =
      "Выберите папку \(Self.folderName(of: agent)) в домашней папке, "
      + "чтобы Flowbar видел лимиты и работу агента."

    NSApp.activate()
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    guard Self.isAgentFolder(url, of: agent) else { return nil }

    save(url, for: agent)
    _ = url.startAccessingSecurityScopedResource()
    accessedFolders[agent] = url
    return url
  }

  // MARK: - Закладки

  private func save(_ url: URL, for agent: Agent) {
    let data = try? url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    defaults.set(data, forKey: Self.bookmarkKey(for: agent))
  }

  private static func bookmarkKey(for agent: Agent) -> String {
    "agentFolderBookmark.\(agent.rawValue)"
  }

  private static func folderName(of agent: Agent) -> String {
    switch agent {
    case .claudeCode: ".claude"
    case .codex: ".codex"
    }
  }

  /// Папка агента узнаётся по каталогу с транскриптами внутри.
  private static func isAgentFolder(_ url: URL, of agent: Agent) -> Bool {
    let marker = AgentFiles.transcripts(of: agent, in: url)
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }
}

/// Раскладка файлов внутри папок агентов.
///
/// Общая для чтения лимитов и наблюдения за работой: пути — одно знание, а не два.
enum AgentFiles {

  /// Каталог, куда агент дописывает транскрипты.
  static func transcripts(of agent: Agent, in folder: URL) -> URL {
    switch agent {
    case .claudeCode: folder.appending(path: "projects", directoryHint: .isDirectory)
    case .codex: folder.appending(path: "sessions", directoryHint: .isDirectory)
    }
  }

  /// Снимок лимитов Claude Code, который пишет statusLine-команда.
  static func claudeSnapshot(in folder: URL) -> URL {
    folder.appending(path: "flowbar-usage.json")
  }

  /// Файлы транскриптов обоих агентов — JSON Lines.
  static let transcriptExtension = "jsonl"
}
