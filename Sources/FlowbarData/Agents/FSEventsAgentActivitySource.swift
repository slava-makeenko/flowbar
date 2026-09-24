import CoreServices
import FlowbarDomain
import Foundation

/// Наблюдает за транскриптами агентов через FSEvents. ADR-0013, ADR-0014, ADR-0017.
///
/// Событийно, без опроса: пока агенты молчат, поток не делает ничего. Ядро само копит
/// события и отдаёт их пачкой не чаще раза в секунду; на каждую пачку читается хвост
/// изменившихся транскриптов.
///
/// FSEvents сообщает об изменении файла при его закрытии. Claude закрывает транскрипт
/// после каждой строки, а Codex держит rollout открытым всю сессию — поэтому у Codex
/// наблюдаются ещё и файлы, которые пишет его хук.
public struct FSEventsAgentActivitySource: AgentActivityObserving {

  /// Создаёт источник.
  public init() {}

  /// Поток изменений транскриптов агента.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  /// - Returns: поток; если наблюдение не поднялось, он сразу завершается.
  public func changes(of agent: Agent, in folder: URL) -> AsyncStream<TranscriptChange> {
    let reader = TranscriptReader(agent: agent, folder: folder)
    return AsyncStream { continuation in
      let watcher = TranscriptWatcher(
        directories: reader.watchedDirectories,
        accepts: reader.accepts
      ) { paths in
        for path in paths {
          if let change = reader.change(at: path) { continuation.yield(change) }
        }
      }
      continuation.onTermination = { _ in watcher.stop() }
      if !watcher.start() { continuation.finish() }
    }
  }
}

/// Превращает путь изменившегося транскрипта в изменение с разобранным ходом.
///
/// `@unchecked Sendable` безопасна: вызывается только из колбэка `FSEventStream`, то есть
/// с одной последовательной очереди.
private final class TranscriptReader: @unchecked Sendable {

  /// События хука старше этого удаляются при запуске наблюдения: сессии давно кончились.
  private static let hookEventLifetime: TimeInterval = 24 * 60 * 60

  private let agent: Agent
  private let hookEvents: URL?

  /// Каталоги, за которыми следить.
  let watchedDirectories: [URL]

  /// Признак субагента Codex читается из первой строки один раз на файл.
  private var codexSubagents: [String: Bool] = [:]

  init(agent: Agent, folder: URL) {
    self.agent = agent
    let transcripts = AgentFiles.transcripts(of: agent, in: folder)
    switch agent {
    case .claudeCode:
      hookEvents = nil
      watchedDirectories = [transcripts]
    case .codex:
      let hookEvents = AgentFiles.codexHookEvents(in: folder)
      Self.prepare(hookEvents)
      self.hookEvents = hookEvents
      watchedDirectories = [transcripts, hookEvents]
    }
  }

  /// Интересен ли путь: транскрипт или событие хука.
  var accepts: @Sendable (String) -> Bool {
    let hookPrefix = hookEvents.map { $0.path + "/" }
    return { path in
      let url = URL(filePath: path)
      if let hookPrefix, path.hasPrefix(hookPrefix) { return url.pathExtension == "json" }
      return url.pathExtension == AgentFiles.transcriptExtension
    }
  }

  func change(at path: String) -> TranscriptChange? {
    let url = URL(filePath: path)
    if let hookEvents, path.hasPrefix(hookEvents.path + "/") {
      return hookChange(at: url)
    }
    let tail = AgentFiles.tail(of: url, length: TurnStateParser.tailLength) ?? ""
    let turn: TurnState?
    switch agent {
    case .claudeCode: turn = TurnStateParser.claude(tail: tail)
    case .codex: turn = TurnStateParser.codex(tail: tail)
    }
    return TranscriptChange(
      agent: agent,
      session: path,
      isSubagent: isSubagent(path, url: url),
      turn: turn
    )
  }

  /// Событие хука: файл целиком — JSON, который Codex передал хуку.
  private func hookChange(at url: URL) -> TranscriptChange? {
    guard
      let data = try? Data(contentsOf: url),
      let event = TurnStateParser.codexHook(payload: String(decoding: data, as: UTF8.self))
    else { return nil }
    return TranscriptChange(
      agent: agent,
      session: event.session,
      isSubagent: false,
      turn: event.turn,
      source: .hook
    )
  }

  /// Создаёт каталог событий — FSEvents следит только за существующим — и убирает
  /// события давно кончившихся сессий.
  private static func prepare(_ directory: URL) {
    let fileManager = FileManager.default
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let threshold = Date().addingTimeInterval(-hookEventLifetime)
    let files =
      (try? fileManager.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    for file in files {
      let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate
      if let modified, modified < threshold { try? fileManager.removeItem(at: file) }
    }
  }

  /// Субагенты Claude пишут в `<сессия>/subagents/`, у Codex признак — в `session_meta`.
  private func isSubagent(_ path: String, url: URL) -> Bool {
    switch agent {
    case .claudeCode:
      return url.pathComponents.contains(AgentFiles.claudeSubagentsDirectory)
    case .codex:
      if let known = codexSubagents[path] { return known }
      let isSubagent = AgentFiles.firstLine(of: url).map {
        TurnStateParser.isCodexSubagent(sessionMeta: $0)
      }
      // Непрочитанную строку не кэшируем: файл мог быть ещё пустым.
      if let isSubagent { codexSubagents[path] = isSubagent }
      return isSubagent ?? false
    }
  }
}

/// Обёртка над `FSEventStream`.
///
/// `@unchecked Sendable` безопасна: поток создаётся, обслуживается и останавливается
/// на одной последовательной очереди, другого изменяемого состояния нет.
///
/// Ссылка в контексте потока не удерживающая: наблюдателя держит `onTermination`
/// асинхронного потока, и он же останавливает `FSEventStream` до освобождения.
private final class TranscriptWatcher: @unchecked Sendable {

  /// Задержка доставки: события за секунду склеиваются в одну пачку.
  private static let latency: CFTimeInterval = 1

  /// Изменения, которые означают, что агент пишет.
  private static let writeFlags = FSEventStreamEventFlags(
    kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemModified
  )

  private let directories: [URL]
  private let accepts: @Sendable (String) -> Bool
  private let onWrite: @Sendable ([String]) -> Void
  private let queue = DispatchQueue(label: "Flowbar.TranscriptWatcher")
  private var stream: FSEventStreamRef?

  init(
    directories: [URL],
    accepts: @escaping @Sendable (String) -> Bool,
    onWrite: @escaping @Sendable ([String]) -> Void
  ) {
    self.directories = directories
    self.accepts = accepts
    self.onWrite = onWrite
  }

  /// Поднимает поток.
  /// - Returns: `false`, если система отказала — например, каталога нет.
  func start() -> Bool {
    queue.sync {
      var context = FSEventStreamContext(
        version: 0,
        info: Unmanaged.passUnretained(self).toOpaque(),
        retain: nil,
        release: nil,
        copyDescription: nil
      )
      let flags = FSEventStreamCreateFlags(
        kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
      )
      guard
        let stream = FSEventStreamCreate(
          kCFAllocatorDefault,
          Self.callback,
          &context,
          directories.map(\.path) as CFArray,
          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
          Self.latency,
          flags
        )
      else { return false }

      FSEventStreamSetDispatchQueue(stream, queue)
      guard FSEventStreamStart(stream) else {
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        return false
      }
      self.stream = stream
      return true
    }
  }

  /// Останавливает поток. Колбэки после возврата не приходят.
  func stop() {
    queue.sync {
      guard let stream else { return }
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
      self.stream = nil
    }
  }

  /// Пути из пачки без повторов: в пачке один файл встречается по разу на каждую запись.
  private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
    var seen = Set<String>()
    let written = zip(paths, flags).compactMap { path, flag in
      isWrite(path: path, flag: flag) && seen.insert(path).inserted ? path : nil
    }
    if !written.isEmpty { onWrite(written) }
  }

  /// Запись — это создание или изменение интересного файла, который всё ещё на месте.
  ///
  /// Проверка существования отсекает `codex archive`: он переносит файл из `sessions`,
  /// и старый путь приходит событием, хотя агент не работает.
  private func isWrite(path: String, flag: FSEventStreamEventFlags) -> Bool {
    guard flag & Self.writeFlags != 0,
      flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0,
      accepts(path)
    else { return false }
    return FileManager.default.fileExists(atPath: path)
  }

  private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
    guard let info else { return }
    let watcher = Unmanaged<TranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
    let list = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
    let flagList = Array(UnsafeBufferPointer(start: flags, count: count))
    watcher.handle(paths: list, flags: flagList)
  }
}
