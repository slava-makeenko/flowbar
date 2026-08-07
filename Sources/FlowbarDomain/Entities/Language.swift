import Foundation

/// Язык перевода, заданный кодом BCP-47.
public struct Language: Hashable, Sendable {

  /// Код языка: `ru`, `en`, `de`.
  public let code: String

  /// Создаёт язык по коду.
  /// - Parameter code: код BCP-47.
  public init(code: String) {
    self.code = code
  }
}

/// Результат попытки перевода.
public enum TranslationOutcome: Equatable, Sendable {

  /// Перевод получен.
  case translated(String)

  /// Переводить нечего — ввод пуст.
  case empty

  /// Языковой пакет недоступен: система его не скачала или пользователь отказался.
  ///
  /// Это не ошибка, а штатный исход: пользователю показывается статус, а не алерт.
  case unavailable

  /// Запрос отменён более свежим вводом.
  case cancelled
}
