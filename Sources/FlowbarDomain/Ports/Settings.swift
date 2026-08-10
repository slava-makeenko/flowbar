import Foundation

/// Запуск приложения при входе в систему.
public protocol LaunchAtLoginControlling: Sendable {

  /// Включён ли автозапуск сейчас.
  var isEnabled: Bool { get async }

  /// Включает или выключает автозапуск.
  ///
  /// Возвращает состояние **после** попытки, а не то, о чём просили: система вправе
  /// отказать, и вьюха должна показать правду, а не намерение.
  /// - Parameter enabled: желаемое состояние.
  /// - Returns: фактическое состояние.
  @discardableResult
  func setEnabled(_ enabled: Bool) async -> Bool
}

/// Хранимые настройки приложения.
public protocol SettingsStoring: Sendable {

  /// Сколько живёт запись в истории копирований.
  var historyLifetime: TimeInterval { get async }

  /// Меняет срок жизни записи.
  /// - Parameter lifetime: новый срок.
  func setHistoryLifetime(_ lifetime: TimeInterval) async
}
