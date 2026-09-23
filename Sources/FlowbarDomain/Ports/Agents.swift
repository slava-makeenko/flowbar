import Foundation

/// Доступ к папкам агентов: `~/.claude` и `~/.codex`.
///
/// Под песочницей доступ — не факт, а разрешение: пользователь выбирает каждую папку
/// один раз, дальше доступ живёт в security-scoped bookmark. ADR-0012.
public protocol AgentFolderAccessing: Sendable {

  /// Папка агента, доступ к которой уже есть.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если разрешения ещё нет.
  func currentFolder(for agent: Agent) async -> URL?

  /// Просит пользователя выбрать папку агента.
  /// - Parameter agent: агент.
  /// - Returns: папка или `nil`, если пользователь отказался или выбрал не ту.
  ///   Причины не различаются: в обоих случаях интерфейс просто напоминает, какая папка нужна.
  func requestFolder(for agent: Agent) async -> URL?
}

/// Чтение последнего снимка лимитов.
public protocol AgentUsageReading: Sendable {

  /// Читает снимок лимитов агента.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  /// - Returns: снимок или `nil`, если данных нет или формат не разобран.
  func usage(of agent: Agent, in folder: URL) async -> AgentUsage?
}

/// Наблюдение за записями агента в транскрипты.
public protocol AgentActivityObserving: Sendable {

  /// Поток записей: элемент приходит, когда агент дописал транскрипт.
  ///
  /// Реализация обязана быть событийной, а не опросом: поток живёт всё время работы
  /// приложения. ADR-0013.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента.
  /// - Returns: поток, завершающийся при отмене подписчика.
  func writes(of agent: Agent, in folder: URL) -> AsyncStream<Void>
}
