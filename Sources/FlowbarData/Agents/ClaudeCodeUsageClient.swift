import FlowbarDomain
import Foundation

/// Живой запрос лимитов у Claude Code через `get_usage` протокола SDK. ADR-0016.
///
/// Запускает `claude` в режиме stream-json, отправляет один служебный запрос и ждёт ответа.
/// Модель не вызывается, лимит не тратится; токен читает и обновляет сам Claude Code —
/// Flowbar его не видит.
public actor ClaudeCodeUsageClient {

  /// Сколько ждать ответа: холодный старт CLI — 1–3 с, дальше — сетевой запрос.
  public static let timeout: Duration = .seconds(15)

  /// Итог запроса.
  public enum Outcome: Sendable {

    /// Лимиты получены.
    case usage(AgentUsage)

    /// Запрос не дал цифр.
    case problem(LiveUsageProblem)
  }

  private var inFlight: Task<Outcome, Never>?

  /// Создаёт клиента.
  public init() {}

  /// Спрашивает лимиты. Параллельный вызов ждёт уже идущий запрос, а не запускает второй CLI.
  /// - Returns: снимок или причина, по которой его нет.
  public func fetch() async -> Outcome {
    if let inFlight { return await inFlight.value }
    let task = Task.detached(priority: .utility) { await Self.run() }
    inFlight = task
    let result = await task.value
    inFlight = nil
    return result
  }

  // MARK: - Процесс

  private static func run() async -> Outcome {
    guard let executable = executable() else { return .problem(.noResponse) }

    let process = Process()
    let input = Pipe()
    let output = Pipe()
    process.executableURL = executable
    process.arguments = [
      "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
      "--no-session-persistence",
    ]
    process.environment = environment()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    process.currentDirectoryURL = FileManager.default.temporaryDirectory

    do {
      try process.run()
    } catch {
      return .problem(.noResponse)
    }
    input.fileHandleForWriting.write(Data((AgentUsageParser.claudeUsageRequest + "\n").utf8))

    // Чтение строк на отмену не реагирует — оно ждёт данных или конца вывода. Поэтому
    // тайм-аут не отменяет чтение, а завершает процесс: вывод закрывается, чтение кончается.
    let running = RunningProcess(process)
    return await withTaskGroup(of: Outcome.self) { group in
      group.addTask { await response(from: output.fileHandleForReading) }
      group.addTask {
        try? await Task.sleep(for: timeout)
        running.terminate()
        return .problem(.noResponse)
      }
      let first = await group.next() ?? .problem(.noResponse)
      running.terminate()
      group.cancelAll()
      return first
    }
  }

  /// Читает поток до ответа на запрос Flowbar. Остальные строки — инициализация, хуки —
  /// пропускаются.
  private static func response(from handle: FileHandle) async -> Outcome {
    do {
      for try await line in handle.bytes.lines {
        guard AgentUsageParser.isClaudeUsageResponse(line: line) else { continue }
        if let usage = AgentUsageParser.claudeUsageResponse(line: line, measuredAt: Date()) {
          return .usage(usage)
        }
        let unavailable = AgentUsageParser.isClaudeUsageUnavailable(line: line)
        return .problem(unavailable ? .notSignedIn : .noResponse)
      }
    } catch {
      return .problem(.noResponse)
    }
    return .problem(.noResponse)
  }

  // MARK: - Окружение

  /// Где обычно лежит `claude`. Приложение запускается не из шелла, и `PATH` у него короткий.
  private static func candidates() -> [URL] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return [
      home.appending(path: ".local/bin/claude"),
      home.appending(path: ".claude/local/claude"),
      URL(filePath: "/opt/homebrew/bin/claude"),
      URL(filePath: "/usr/local/bin/claude"),
    ]
  }

  private static func executable() -> URL? {
    candidates().first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }

  /// Окружение приложения с каталогами `claude` в `PATH`: хуки плагинов запускают
  /// свои инструменты по имени.
  private static func environment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let extra = candidates().map { $0.deletingLastPathComponent().path }
    let path = environment["PATH"].map { [$0] } ?? []
    environment["PATH"] = (extra + path).joined(separator: ":")
    return environment
  }
}

/// Процесс, который можно завершить из другой задачи.
///
/// `@unchecked Sendable` безопасна: `terminate` у `Process` потокобезопасен, а повторный
/// вызов для завершённого процесса ничего не делает.
private final class RunningProcess: @unchecked Sendable {

  private let process: Process

  init(_ process: Process) {
    self.process = process
  }

  func terminate() {
    if process.isRunning { process.terminate() }
  }
}
