import CoreServices
import FlowbarDomain
import Foundation

/// Наблюдает за транскриптами агентов через FSEvents. ADR-0013.
///
/// Событийно, без опроса: пока агенты молчат, поток не делает ничего. Ядро само копит
/// события и отдаёт их пачкой не чаще раза в секунду.
public struct FSEventsAgentActivitySource: AgentActivityObserving {

  /// Создаёт источник.
  public init() {}

  /// Поток записей агента в транскрипты.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  /// - Returns: поток; если наблюдение не поднялось, он сразу завершается.
  public func writes(of agent: Agent, in folder: URL) -> AsyncStream<Void> {
    let directory = AgentFiles.transcripts(of: agent, in: folder)
    // Важен факт записи, а не их число: из пачки событий хватает последнего.
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let watcher = TranscriptWatcher(directory: directory) { continuation.yield() }
      continuation.onTermination = { _ in watcher.stop() }
      if !watcher.start() { continuation.finish() }
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

  private let directory: URL
  private let onWrite: @Sendable () -> Void
  private let queue = DispatchQueue(label: "Flowbar.TranscriptWatcher")
  private var stream: FSEventStreamRef?

  init(directory: URL, onWrite: @escaping @Sendable () -> Void) {
    self.directory = directory
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
          [directory.path] as CFArray,
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

  private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
    let wrote = zip(paths, flags).contains { path, flag in
      Self.isWrite(path: path, flag: flag)
    }
    if wrote { onWrite() }
  }

  /// Запись — это создание или изменение файла транскрипта, который всё ещё на месте.
  ///
  /// Проверка существования отсекает `codex archive`: он переносит файл из `sessions`,
  /// и старый путь приходит событием, хотя агент не работает.
  private static func isWrite(path: String, flag: FSEventStreamEventFlags) -> Bool {
    guard flag & writeFlags != 0,
      flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0,
      URL(filePath: path).pathExtension == AgentFiles.transcriptExtension
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
