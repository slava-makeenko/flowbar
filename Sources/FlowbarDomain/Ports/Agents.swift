import Foundation

/// Доступ к папкам агентов: `~/.claude` и `~/.codex`.
///
/// Без песочницы папки читаются напрямую; порт остаётся, потому что папки может не быть —
/// агент не установлен. ADR-0016.
public protocol AgentFolderAccessing: Sendable {

  /// Папка агента, доступ к которой уже есть.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если разрешения ещё нет.
  func currentFolder(for agent: Agent) async -> URL?

  /// Проверяет папку агента заново — например, после установки агента.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если её по-прежнему нет.
  func requestFolder(for agent: Agent) async -> URL?
}

/// Чтение последнего снимка лимитов.
public protocol AgentUsageReading: Sendable {

  /// Читает снимок лимитов агента.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  ///   - live: можно ли спросить самого агента, а не только прочитать файлы. Это дорого —
  ///     запуск CLI, — поэтому частоту решает вызывающий. ADR-0016.
  /// - Returns: самый свежий известный снимок или `nil`, если данных нет.
  func usage(of agent: Agent, in folder: URL, live: Bool) async -> AgentUsage?

  /// Почему последний живой запрос не дал цифр.
  /// - Parameter agent: агент.
  /// - Returns: причина или `nil`, если запрос удался или его не было.
  func liveProblem(of agent: Agent) async -> LiveUsageProblem?
}

/// Наблюдение за транскриптами агента.
public protocol AgentActivityObserving: Sendable {

  /// Поток изменений: элемент приходит, когда агент дописал транскрипт сессии.
  ///
  /// Реализация обязана быть событийной, а не опросом: поток живёт всё время работы
  /// приложения. ADR-0013, ADR-0014.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  /// - Returns: поток, завершающийся при отмене подписчика.
  func changes(of agent: Agent, in folder: URL) -> AsyncStream<TranscriptChange>
}

/// Хуки Flowbar в конфиге Codex. ADR-0017.
public protocol CodexHooksInstalling: Sendable {

  /// Стоят ли хуки.
  var isInstalled: Bool { get async }

  /// Ставит недостающие хуки, сохранив прежний конфиг рядом.
  /// - Returns: `true`, если после вызова хуки стоят.
  @discardableResult
  func install() async -> Bool
}
