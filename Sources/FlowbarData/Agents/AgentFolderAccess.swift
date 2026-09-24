import FlowbarDomain
import Foundation

/// Доступ к папкам агентов в домашней папке. ADR-0016.
///
/// Без песочницы выбирать папки не нужно: они читаются напрямую. Папка считается папкой
/// агента, если в ней есть каталог транскриптов, — иначе агент не установлен.
public struct AgentFolderAccess: AgentFolderAccessing {

  /// Создаёт доступ.
  public init() {}

  /// Папка агента в домашней папке пользователя.
  /// - Parameter agent: агент.
  /// - Returns: `~/.claude` или `~/.codex`.
  public static func expectedLocation(of agent: Agent) -> URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: folderName(of: agent), directoryHint: .isDirectory)
  }

  /// Папка агента, если агент установлен.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если каталога транскриптов нет.
  public func currentFolder(for agent: Agent) -> URL? {
    let folder = Self.expectedLocation(of: agent)
    return Self.isAgentFolder(folder, of: agent) ? folder : nil
  }

  /// Проверяет заново: агента могли установить после запуска приложения.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`.
  public func requestFolder(for agent: Agent) -> URL? {
    currentFolder(for: agent)
  }

  private static func folderName(of agent: Agent) -> String {
    switch agent {
    case .claudeCode: ".claude"
    case .codex: ".codex"
    }
  }

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

  /// Каталог, куда хук Flowbar пишет события хода Codex. ADR-0017.
  static func codexHookEvents(in folder: URL) -> URL {
    folder.appending(path: CodexHooks.eventsDirectory, directoryHint: .isDirectory)
  }

  /// Конфиг хуков Codex.
  static func codexHooksConfig(in folder: URL) -> URL {
    folder.appending(path: "hooks.json")
  }

  /// Снимок лимитов Claude Code, который пишет statusLine-команда.
  static func claudeSnapshot(in folder: URL) -> URL {
    folder.appending(path: "flowbar-usage.json")
  }

  /// Каталог внутри сессии Claude Code, куда пишут субагенты.
  static let claudeSubagentsDirectory = "subagents"

  /// Файлы транскриптов обоих агентов — JSON Lines.
  static let transcriptExtension = "jsonl"

  /// Хвост файла. Транскрипты бывают в мегабайты, а нужное всегда в конце.
  /// - Parameters:
  ///   - url: файл.
  ///   - length: сколько байт с конца читать.
  /// - Returns: хвост или `nil`, если файл не читается.
  static func tail(of url: URL, length: Int) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }

    guard let size = try? handle.seekToEnd() else { return nil }
    let length = UInt64(length)
    try? handle.seek(toOffset: size > length ? size - length : 0)
    guard let data = try? handle.readToEnd() else { return nil }
    return String(decoding: data, as: UTF8.self)
  }

  /// Первая строка файла: у rollout-файла Codex это `session_meta`.
  /// - Parameter url: файл.
  /// - Returns: строка или `nil`, если файл не читается.
  static func firstLine(of url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }

    var line = Data()
    while let chunk = try? handle.read(upToCount: firstLineChunk), !chunk.isEmpty {
      if let newline = chunk.firstIndex(of: UInt8(ascii: "\n")) {
        line.append(chunk[..<newline])
        break
      }
      line.append(chunk)
    }
    return String(decoding: line, as: UTF8.self)
  }

  /// Шаг чтения первой строки: `session_meta` Codex несёт базовые инструкции и весит
  /// десятки килобайт.
  private static let firstLineChunk = 16 * 1024
}
