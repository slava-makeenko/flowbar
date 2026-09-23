import FlowbarDomain
import Foundation

/// Экран лимитов Claude Code и Codex. ADR-0012.
@MainActor
@Observable
public final class LimitsViewModel {

  /// Что известно об агенте.
  public enum AgentState: Equatable, Sendable {

    /// Доступа к папке агента ещё нет.
    case needsFolder

    /// Папка доступна, но снимка лимитов в ней нет.
    case noData

    /// Последний известный снимок.
    case usage(AgentUsage)
  }

  /// Как часто перечитывать файлы, пока экран открыт.
  public static let refreshInterval: Duration = .seconds(10)

  /// С какой доли окно считается почти исчерпанным.
  public static let nearLimitPercent: Double = 90

  /// Настройка statusLine для `~/.claude/settings.json`.
  ///
  /// Команда откладывает `rate_limits` из payload в файл и печатает название модели,
  /// чтобы строка состояния не опустела. Проверена на `sh` с payload Claude Code 2.1.267.
  public static let claudeSetupSnippet = #"""
    "statusLine": {
      "type": "command",
      "command": "input=$(cat); printf '%s' \"$input\" | plutil -extract rate_limits json -o \"$HOME/.claude/flowbar-usage.json\" - 2>/dev/null; printf '%s' \"$input\" | plutil -extract model.display_name raw -o - - 2>/dev/null"
    }
    """#

  /// Состояние по агентам.
  public private(set) var states: [Agent: AgentState] = Dictionary(
    uniqueKeysWithValues: Agent.allCases.map { ($0, .needsFolder) }
  )

  /// Агент, для которого пользователь только что выбрал не ту папку.
  public private(set) var rejectedFolder: Agent?

  /// Момент последнего чтения: от него считаются «сброшено» и возраст снимка.
  public private(set) var now: Date

  private let access: any AgentFolderAccessing
  private let reader: any AgentUsageReading
  private let clock: any Clock
  private let pasteboard: any PasteboardWriting
  private let feedback: CopyFeedback
  private let onFolderGranted: @MainActor (Agent, URL) -> Void
  private var folders: [Agent: URL] = [:]

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - access: доступ к папкам агентов.
  ///   - reader: чтение снимков лимитов.
  ///   - clock: часы.
  ///   - pasteboard: запись в пастборд — для настройки statusLine.
  ///   - feedback: подтверждение копирования.
  ///   - onFolderGranted: вызывается, когда доступ к папке агента появился.
  public init(
    access: any AgentFolderAccessing,
    reader: any AgentUsageReading,
    clock: any Clock,
    pasteboard: any PasteboardWriting,
    feedback: CopyFeedback,
    onFolderGranted: @escaping @MainActor (Agent, URL) -> Void
  ) {
    self.access = access
    self.reader = reader
    self.clock = clock
    self.pasteboard = pasteboard
    self.feedback = feedback
    self.onFolderGranted = onFolderGranted
    self.now = clock.now
  }

  /// Состояние агента.
  /// - Parameter agent: агент.
  /// - Returns: состояние.
  public func state(of agent: Agent) -> AgentState {
    states[agent] ?? .needsFolder
  }

  /// Восстанавливает доступ по закладкам. Вызывается на старте приложения, а не при
  /// открытии экрана: индикатору в пилюле папки нужны сразу.
  public func restoreAccess() async {
    for agent in Agent.allCases {
      guard let folder = await access.currentFolder(for: agent) else { continue }
      grant(folder, to: agent)
    }
    await refresh()
  }

  /// Просит пользователя выбрать папку агента.
  /// - Parameter agent: агент.
  public func requestAccess(for agent: Agent) async {
    guard let folder = await access.requestFolder(for: agent) else {
      rejectedFolder = agent
      return
    }
    rejectedFolder = nil
    grant(folder, to: agent)
    await refresh()
  }

  /// Перечитывает снимки, пока экран открыт. Отмена задачи — закрытие экрана.
  public func refreshWhileVisible() async {
    while !Task.isCancelled {
      await refresh()
      try? await Task.sleep(for: Self.refreshInterval)
    }
  }

  /// Кладёт настройку statusLine в буфер обмена.
  public func copyClaudeSetup() async {
    await pasteboard.write(text: Self.claudeSetupSnippet)
    feedback.confirm("Настройка скопирована", item: Agent.claudeCode.rawValue)
  }

  // MARK: - Подписи

  /// Название окна.
  /// - Parameter window: окно.
  /// - Returns: «5 часов», «Неделя».
  public nonisolated static func title(for window: UsageWindow) -> String {
    let hours = Int((window.duration / 3600).rounded())
    if hours % 24 == 0 {
      let days = hours / 24
      return days == 7 ? "Неделя" : "\(days) \(plural(days, "день", "дня", "дней"))"
    }
    return "\(hours) \(plural(hours, "час", "часа", "часов"))"
  }

  /// Израсходованная доля на текущий момент.
  /// - Parameter window: окно.
  /// - Returns: «96 %».
  public func percentText(for window: UsageWindow) -> String {
    let percent = Int(window.usedPercent(at: now).rounded())
    return "\(percent) %"
  }

  /// Доля от 0 до 1 для полосы.
  /// - Parameter window: окно.
  /// - Returns: доля.
  public func fraction(of window: UsageWindow) -> Double {
    window.usedPercent(at: now) / 100
  }

  /// Почти исчерпано ли окно.
  /// - Parameter window: окно.
  /// - Returns: `true`, если израсходовано не меньше порога.
  public func isNearLimit(_ window: UsageWindow) -> Bool {
    window.usedPercent(at: now) >= Self.nearLimitPercent
  }

  /// Когда окно сбросится.
  /// - Parameter window: окно.
  /// - Returns: «сброс в 19:40», «сброс пт в 10:15» или «сброшено».
  public func resetText(for window: UsageWindow) -> String {
    guard window.resetsAt > now else { return "сброшено" }
    let time = window.resetsAt.formatted(
      .dateTime.hour().minute().locale(InterfaceLocale.current)
    )
    guard !Calendar.current.isDate(window.resetsAt, inSameDayAs: now) else {
      return "сброс в \(time)"
    }
    let day = window.resetsAt.formatted(
      .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(InterfaceLocale.current)
    )
    return "сброс \(day) в \(time)"
  }

  /// Возраст снимка: данные обновляются, только пока агент работает.
  /// - Parameter usage: снимок.
  /// - Returns: «данные 12 минут назад».
  public func ageText(for usage: AgentUsage) -> String {
    let moment = min(usage.measuredAt, now).formatted(
      .relative(presentation: .named).locale(InterfaceLocale.current)
    )
    return "данные \(moment)"
  }

  // MARK: - Чтение

  private func grant(_ folder: URL, to agent: Agent) {
    guard folders[agent] == nil else { return }
    folders[agent] = folder
    states[agent] = .noData
    onFolderGranted(agent, folder)
  }

  private func refresh() async {
    now = clock.now
    for (agent, folder) in folders {
      let usage = await reader.usage(of: agent, in: folder)
      states[agent] = usage.map(AgentState.usage) ?? .noData
    }
  }

  private nonisolated static func plural(
    _ count: Int,
    _ one: String,
    _ few: String,
    _ many: String
  ) -> String {
    let remainderTen = count % 10
    let remainderHundred = count % 100
    if remainderTen == 1 && remainderHundred != 11 { return one }
    if (2...4).contains(remainderTen) && !(12...14).contains(remainderHundred) { return few }
    return many
  }
}
