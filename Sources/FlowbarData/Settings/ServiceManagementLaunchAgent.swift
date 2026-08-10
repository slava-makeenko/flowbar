import FlowbarDomain
import Foundation
import ServiceManagement

/// Автозапуск через `SMAppService`.
///
/// Это штатный способ с macOS 13: приложение регистрирует само себя, отдельный
/// хелпер-агент и правка `~/Library/LaunchAgents` не нужны. Пользователь видит запись
/// в «Объектах входа» и может выключить её оттуда — состояние читается заново каждый раз.
public struct ServiceManagementLaunchAgent: LaunchAtLoginControlling {

  /// Создаёт адаптер.
  public init() {}

  /// Включён ли автозапуск.
  public var isEnabled: Bool {
    get async { SMAppService.mainApp.status == .enabled }
  }

  /// Включает или выключает автозапуск.
  /// - Parameter enabled: желаемое состояние.
  /// - Returns: фактическое состояние после попытки.
  @discardableResult
  public func setEnabled(_ enabled: Bool) async -> Bool {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try await SMAppService.mainApp.unregister()
      }
    } catch {
      // Отказ системы — штатный исход: пользователь мог запретить автозапуск в настройках.
      // Возвращаем фактическое состояние, а не то, о чём просили.
    }
    return SMAppService.mainApp.status == .enabled
  }
}

/// Настройки в `UserDefaults`.
public struct UserDefaultsSettingsStore: SettingsStoring {

  private static let historyLifetimeKey = "historyLifetime"

  private let fallbackLifetime: TimeInterval

  /// Создаёт хранилище.
  ///
  /// `UserDefaults` не хранится в свойстве, а берётся при каждом обращении: тип
  /// не `Sendable`, а порт обязан им быть.
  /// - Parameter fallbackLifetime: срок, пока пользователь ничего не выбирал.
  public init(fallbackLifetime: TimeInterval) {
    self.fallbackLifetime = fallbackLifetime
  }

  /// Срок жизни записи в истории.
  public var historyLifetime: TimeInterval {
    get async {
      let stored = UserDefaults.standard.double(forKey: Self.historyLifetimeKey)
      return stored > 0 ? stored : fallbackLifetime
    }
  }

  /// Меняет срок жизни записи.
  /// - Parameter lifetime: новый срок.
  public func setHistoryLifetime(_ lifetime: TimeInterval) async {
    UserDefaults.standard.set(lifetime, forKey: Self.historyLifetimeKey)
  }
}
