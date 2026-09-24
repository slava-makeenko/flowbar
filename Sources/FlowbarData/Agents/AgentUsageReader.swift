import FlowbarDomain
import Foundation

/// Читает самый свежий снимок лимитов агента. ADR-0012, ADR-0016.
///
/// Codex — всегда из rollout-файлов: их пишут и CLI, и десктопное приложение. Claude Code —
/// живым запросом `get_usage`, если его разрешили, а снимок statusLine — запасной. Из двух
/// побеждает более свежий: снимок читается часто, живой запрос редко, и без этого правила
/// экран откатывался бы к старым цифрам между запросами.
public actor AgentUsageReader: AgentUsageReading {

  /// Сколько самых свежих rollout-файлов Codex просматривать, пока не найдётся снимок.
  private static let codexFilesToScan = 3

  private let claudeClient: ClaudeCodeUsageClient
  private var lastLiveClaude: AgentUsage?

  /// Создаёт читателя.
  /// - Parameter claudeClient: живой запрос лимитов Claude Code.
  public init(claudeClient: ClaudeCodeUsageClient = ClaudeCodeUsageClient()) {
    self.claudeClient = claudeClient
  }

  /// Читает самый свежий снимок лимитов агента.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  ///   - live: можно ли спросить самого агента.
  /// - Returns: снимок или `nil`, если данных нет.
  public func usage(of agent: Agent, in folder: URL, live: Bool) async -> AgentUsage? {
    switch agent {
    case .claudeCode: await claude(in: folder, live: live)
    case .codex: Self.codex(in: folder)
    }
  }

  // MARK: - Claude Code

  private func claude(in folder: URL, live: Bool) async -> AgentUsage? {
    if live, let fetched = await claudeClient.fetch() { lastLiveClaude = fetched }
    let candidates = [lastLiveClaude, Self.claudeSnapshot(in: folder)].compactMap { $0 }
    guard let newest = candidates.max(by: { $0.measuredAt < $1.measuredAt }) else {
      return nil
    }
    return newest.withLastActivity(Self.claudeLastActivity(in: folder))
  }

  /// Снимок, который пишет statusLine терминального `claude`. ADR-0012.
  private static func claudeSnapshot(in folder: URL) -> AgentUsage? {
    let url = AgentFiles.claudeSnapshot(in: folder)
    guard
      let data = try? Data(contentsOf: url),
      let modified = modificationDate(of: url)
    else { return nil }
    return AgentUsageParser.claude(snapshot: data, measuredAt: modified)
  }

  /// Последняя работа Claude: по ней видно, что снимок отстал от неё.
  private static func claudeLastActivity(in folder: URL) -> Date? {
    transcriptFiles(in: AgentFiles.transcripts(of: .claudeCode, in: folder))
      .filter { !$0.url.pathComponents.contains(AgentFiles.claudeSubagentsDirectory) }
      .map(\.modified)
      .max()
  }

  // MARK: - Codex

  /// Самый свежий файл ищется по дате изменения, а не по имени каталога: долгая сессия
  /// живёт в каталоге дня, когда началась, и дописывается днями позже.
  private static func codex(in folder: URL) -> AgentUsage? {
    let rollouts = transcriptFiles(in: AgentFiles.transcripts(of: .codex, in: folder))
      .sorted { $0.modified > $1.modified }
      .prefix(codexFilesToScan)

    for file in rollouts {
      if let tail = AgentFiles.tail(of: file.url, length: AgentUsageParser.codexTailLength),
        let usage = AgentUsageParser.codex(tail: tail)
      {
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

  private static func modificationDate(of url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
  }
}
