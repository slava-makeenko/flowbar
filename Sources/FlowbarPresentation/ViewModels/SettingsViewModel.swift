import FlowbarDomain
import Foundation

/// Экран настроек.
@MainActor
@Observable
public final class SettingsViewModel {

  /// Сроки хранения истории, доступные в интерфейсе.
  public static let offeredLifetimes: [TimeInterval] = [
    24 * 60 * 60,
    7 * 24 * 60 * 60,
    30 * 24 * 60 * 60,
  ]

  /// Открывать ли приложение при входе в систему.
  public private(set) var launchesAtLogin = false

  /// Текущий срок хранения истории.
  public private(set) var historyLifetime: TimeInterval = 0

  private let launchAgent: any LaunchAtLoginControlling
  private let settings: any SettingsStoring

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - launchAgent: управление автозапуском.
  ///   - settings: хранимые настройки.
  public init(launchAgent: any LaunchAtLoginControlling, settings: any SettingsStoring) {
    self.launchAgent = launchAgent
    self.settings = settings
  }

  /// Читает текущее состояние.
  ///
  /// Именно читает, а не помнит: автозапуск пользователь может выключить в системных
  /// настройках, и наше представление о нём устареет.
  public func load() async {
    launchesAtLogin = await launchAgent.isEnabled
    historyLifetime = await settings.historyLifetime
  }

  /// Переключает автозапуск.
  /// - Parameter enabled: желаемое состояние.
  public func setLaunchesAtLogin(_ enabled: Bool) async {
    launchesAtLogin = await launchAgent.setEnabled(enabled)
  }

  /// Меняет срок хранения истории.
  /// - Parameter lifetime: новый срок.
  public func setHistoryLifetime(_ lifetime: TimeInterval) async {
    await settings.setHistoryLifetime(lifetime)
    historyLifetime = lifetime
  }

  /// Подпись срока хранения.
  /// - Parameter lifetime: срок в секундах.
  /// - Returns: строка вида «7 дней».
  public nonisolated static func title(for lifetime: TimeInterval) -> String {
    let days = Int((lifetime / (24 * 60 * 60)).rounded())
    return "\(days) \(Self.dayWord(days))"
  }

  private nonisolated static func dayWord(_ days: Int) -> String {
    let remainderTen = days % 10
    let remainderHundred = days % 100
    if remainderTen == 1 && remainderHundred != 11 { return "день" }
    if (2...4).contains(remainderTen) && !(12...14).contains(remainderHundred) { return "дня" }
    return "дней"
  }
}
