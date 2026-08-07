import Foundation

/// Перевод текста.
public protocol TextTranslating: Sendable {

  /// Переводит текст.
  ///
  /// Недоступный языковой пакет — штатный исход `.unavailable`, а не ошибка: система
  /// спрашивает разрешение на скачивание, и пользователь вправе отказаться.
  /// - Parameters:
  ///   - text: исходный текст.
  ///   - source: исходный язык; `nil` — определять автоматически.
  ///   - target: язык перевода.
  /// - Returns: исход перевода.
  func translate(_ text: String, from source: Language?, to target: Language) async
    -> TranslationOutcome
}

/// Определение языка текста.
public protocol LanguageDetecting: Sendable {

  /// Определяет язык.
  /// - Parameter text: текст.
  /// - Returns: язык или `nil`, если уверенности нет.
  func language(of text: String) -> Language?
}
