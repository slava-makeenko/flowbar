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

  /// Как часто спрашивать самих агентов, пока экран открыт. Реже файлов: каждый живой
  /// запрос — запуск CLI. ADR-0016.
  public static let liveRefreshInterval: TimeInterval = 60

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

  /// Момент последнего чтения: от него считаются «сброшено» и возраст снимка.
  public private(set) var now: Date

  private let access: any AgentFolderAccessing
  private let reader: any AgentUsageReading
  private let clock: any Clock
  private let pasteboard: any PasteboardWriting
  private let feedback: CopyFeedback
  private let onFolderGranted: @MainActor (Agent, URL) -> Void
  private var folders: [Agent: URL] = [:]
  private var lastLiveRefresh: Date?

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
    await refresh(live: false)
  }

  /// Проверяет папку агента заново — например, после установки агента.
  /// - Parameter agent: агент.
  public func requestAccess(for agent: Agent) async {
    guard let folder = await access.requestFolder(for: agent) else { return }
    grant(folder, to: agent)
    await refresh(live: true)
  }

  /// Перечитывает снимки, пока экран открыт. Отмена задачи — закрытие экрана.
  ///
  /// Файлы — раз в 10 с, живой запрос — при открытии и раз в минуту.
  public func refreshWhileVisible() async {
    lastLiveRefresh = nil
    while !Task.isCancelled {
      let isLiveDue =
        lastLiveRefresh.map {
          clock.now.timeIntervalSince($0) >= Self.liveRefreshInterval
        } ?? true
      await refresh(live: isLiveDue)
      try? await Task.sleep(for: Self.refreshInterval)
    }
  }

  /// Идентификатор кнопки перечитывания для галочки подтверждения.
  public static let refreshItem = "limits.refresh"

  /// Перечитывает снимки сейчас, не дожидаясь очередного круга.
  ///
  /// Перечитывает только то, что агенты уже записали: запросить у них свежие цифры
  /// приложение не может, ADR-0012. Подтверждение нужно, потому что цифры часто не
  /// меняются, и без него кнопка выглядела бы сломанной.
  public func refreshNow() async {
    await refresh(live: true)
    feedback.confirm("Лимиты перечитаны", item: Self.refreshItem)
  }

  /// Подтверждена ли только что кнопка перечитывания.
  public var isRefreshConfirmed: Bool {
    feedback.confirmingItem == Self.refreshItem
  }

  /// Кладёт настройку statusLine — запасного источника — в буфер обмена.
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
    window.usedPercent(at: now) >= LimitAdvice.nearLimitPercent
  }

  /// Когда окно сбросится.
  /// - Parameter window: окно.
  /// - Returns: «сброс в 19:40», «сброс пт, 25 сент. в 10:15» или «сброшено».
  public func resetText(for window: UsageWindow) -> String {
    guard window.resetsAt > now else { return "сброшено" }
    return "сброс \(momentText(window.resetsAt))"
  }

  /// Прогноз окна по среднему темпу. ADR-0015.
  /// - Parameters:
  ///   - window: окно.
  ///   - usage: снимок, которому окно принадлежит.
  /// - Returns: «кончится ≈ в 16:40», «хватит до сброса» или `nil`, если прогноза нет.
  public func forecastText(for window: UsageWindow, of usage: AgentUsage) -> String? {
    guard now < window.resetsAt, !usage.isOutdated else { return nil }
    switch window.forecast(measuredAt: usage.measuredAt) {
    case .runsOut(let moment): return "по темпу кончится ≈ \(momentText(moment))"
    case .lastsUntilReset: return "по темпу хватит до сброса"
    case nil: return nil
    }
  }

  /// Кончится ли окно раньше сброса по прогнозу.
  /// - Parameters:
  ///   - window: окно.
  ///   - usage: снимок, которому окно принадлежит.
  /// - Returns: `true`, если прогноз — «кончится».
  public func runsOut(_ window: UsageWindow, of usage: AgentUsage) -> Bool {
    guard now < window.resetsAt, !usage.isOutdated,
      case .runsOut = window.forecast(measuredAt: usage.measuredAt)
    else { return false }
    return true
  }

  /// Совет переключиться для агента, у которого окно кончается.
  /// - Parameter agent: агент.
  /// - Returns: «У Codex за 5 часов занято 30 %» или `nil`.
  public func adviceText(for agent: Agent) -> String? {
    let usages = Agent.allCases.compactMap { agent -> AgentUsage? in
      guard case .usage(let usage) = state(of: agent) else { return nil }
      return usage
    }
    guard let advice = LimitAdvice.find(in: usages, at: now), advice.from == agent else {
      return nil
    }
    let title = Self.title(for: advice.window).lowercased()
    return "У \(advice.to.title) за \(title) занято \(percentText(for: advice.window))"
  }

  /// Предупреждение о заведомо устаревшем снимке.
  /// - Parameter usage: снимок.
  /// - Returns: пояснение или `nil`, если снимок не устарел.
  public func outdatedText(for usage: AgentUsage) -> String? {
    guard usage.isOutdated else { return nil }
    switch usage.agent {
    case .claudeCode:
      return "Устарело: Claude работал после снимка — нажмите ↻, чтобы спросить заново"
    case .codex:
      return "Устарело: Codex работал после снимка"
    }
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

  /// Момент: «в 19:40» сегодня, «пт, 25 сент. в 10:15» в другой день.
  private func momentText(_ moment: Date) -> String {
    let time = moment.formatted(.dateTime.hour().minute().locale(InterfaceLocale.current))
    guard !Calendar.current.isDate(moment, inSameDayAs: now) else { return "в \(time)" }
    let day = moment.formatted(
      .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(InterfaceLocale.current)
    )
    return "\(day) в \(time)"
  }

  // MARK: - Чтение

  private func grant(_ folder: URL, to agent: Agent) {
    guard folders[agent] == nil else { return }
    folders[agent] = folder
    states[agent] = .noData
    onFolderGranted(agent, folder)
  }

  private func refresh(live: Bool) async {
    if live { lastLiveRefresh = clock.now }
    for (agent, folder) in folders {
      let usage = await reader.usage(of: agent, in: folder, live: live)
      states[agent] = usage.map(AgentState.usage) ?? .noData
    }
    // После чтения: живой запрос идёт секунды, и подписи должны считаться от ответа.
    now = clock.now
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
