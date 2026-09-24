import FlowbarDomain
import Foundation

/// Читает последний снимок лимитов из файлов агентов. ADR-0012.
public struct FileAgentUsageReader: AgentUsageReading {

  /// Сколько самых свежих rollout-файлов Codex просматривать, пока не найдётся снимок.
  private static let codexFilesToScan = 3

  /// Создаёт читателя.
  public init() {}

  /// Читает снимок лимитов агента.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  /// - Returns: снимок или `nil`, если данных нет или формат не разобран.
  public func usage(of agent: Agent, in folder: URL) async -> AgentUsage? {
    switch agent {
    case .claudeCode: Self.claude(in: folder)
    case .codex: Self.codex(in: folder)
    }
  }

  // MARK: - Claude Code

  private static func claude(in folder: URL) -> AgentUsage? {
    let url = AgentFiles.claudeSnapshot(in: folder)
    guard
      let data = try? Data(contentsOf: url),
      let modified = modificationDate(of: url)
    else { return nil }
    return AgentUsageParser.claude(snapshot: data, measuredAt: modified)
  }

  // MARK: - Codex

  /// Самый свежий файл ищется по дате изменения, а не по имени каталога: долгая сессия
  /// живёт в каталоге дня, когда началась, и дописывается днями позже.
  private static func codex(in folder: URL) -> AgentUsage? {
    let rollouts = transcriptFiles(in: AgentFiles.transcripts(of: .codex, in: folder))
      .sorted { $0.modified > $1.modified }
      .prefix(codexFilesToScan)

    for file in rollouts {
      if let tail = tail(of: file.url), let usage = AgentUsageParser.codex(tail: tail) {
        return usage
      }
    }
    return nil
  }

  private static func transcriptFiles(in directory: URL) -> [(url: URL, modified: Date)] {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      )
    else { return [] }

    var files: [(url: URL, modified: Date)] = []
    for case let url as URL in enumerator
    where url.pathExtension == AgentFiles.transcriptExtension {
      let values = try? url.resourceValues(forKeys: [
        .contentModificationDateKey, .isRegularFileKey,
      ])
      guard values?.isRegularFile == true, let modified = values?.contentModificationDate
      else { continue }
      files.append((url, modified))
    }
    return files
  }

  /// Хвост файла. Rollout-файлы бывают в мегабайты, а снимок всегда в конце.
  private static func tail(of url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }

    guard let size = try? handle.seekToEnd() else { return nil }
    let length = UInt64(AgentUsageParser.codexTailLength)
    try? handle.seek(toOffset: size > length ? size - length : 0)
    guard let data = try? handle.readToEnd() else { return nil }
    return String(decoding: data, as: UTF8.self)
  }

  private static func modificationDate(of url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }
}
