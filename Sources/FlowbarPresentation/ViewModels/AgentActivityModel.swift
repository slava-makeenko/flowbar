import FlowbarDomain
import Foundation

/// Индикатор работы агентов в свёрнутой пилюле. ADR-0013.
///
/// Гасит индикатор разовой задачей ровно в момент, который вернуло правило, — периодического
/// таймера нет: пока агенты молчат, модель ничего не делает.
@MainActor
@Observable
public final class AgentActivityModel {

  /// Работающие агенты в порядке показа: Claude Code сверху.
  public private(set) var working: [Agent] = []

  private var activity: AgentActivity
  private let observer: any AgentActivityObserving
  private let clock: any Clock
  private var watches: [Agent: Task<Void, Never>] = [:]
  private var fadeTask: Task<Void, Never>?

  /// Создаёт модель.
  /// - Parameters:
  ///   - observer: наблюдение за транскриптами.
  ///   - clock: часы.
  ///   - holdWindow: сколько агент считается работающим после записи.
  public init(
    observer: any AgentActivityObserving,
    clock: any Clock,
    holdWindow: TimeInterval = AgentActivity.defaultHoldWindow
  ) {
    self.observer = observer
    self.clock = clock
    self.activity = AgentActivity(holdWindow: holdWindow)
  }

  /// Метка для VoiceOver; `nil`, когда агенты не работают.
  public var accessibilityLabel: String? {
    guard !working.isEmpty else { return nil }
    let names = working.map(\.title).joined(separator: " и ")
    return working.count == 1 ? "\(names) работает" : "\(names) работают"
  }

  /// Начинает следить за агентом. Повторный вызов для того же агента ничего не делает.
  /// - Parameters:
  ///   - agent: агент.
  ///   - folder: папка агента с выданным доступом.
  public func watch(_ agent: Agent, in folder: URL) {
    guard watches[agent] == nil else { return }
    let writes = observer.writes(of: agent, in: folder)
    watches[agent] = Task { [weak self] in
      for await _ in writes {
        self?.recordWrite(by: agent)
      }
    }
  }

  private func recordWrite(by agent: Agent) {
    activity.recordWrite(by: agent, at: clock.now)
    update()
  }

  private func update() {
    let now = clock.now
    let current = activity.working(at: now)
    let ordered = Agent.allCases.filter(current.contains)
    // Присваивание без изменений всё равно будит наблюдателей и перерисовку пилюли.
    if ordered != working { working = ordered }

    fadeTask?.cancel()
    guard let next = activity.nextChange(after: now) else { return }
    fadeTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(next.timeIntervalSince(now)))
      guard !Task.isCancelled else { return }
      self?.update()
    }
  }
}
