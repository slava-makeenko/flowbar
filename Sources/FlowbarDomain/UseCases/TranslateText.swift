import Foundation

/// Переводит текст, отменяя предыдущий запрос.
///
/// Тип заведён ради решения: отмена устаревшей задачи, определение языка и штатная
/// обработка недоступного языкового пакета. Без отмены результат предыдущего запроса
/// «догоняет» и перезаписывает свежий перевод.
public actor TranslateText {

  private let translator: any TextTranslating
  private let languageDetector: any LanguageDetecting

  private var inFlight: Task<TranslationOutcome, Never>?

  /// Создаёт юзкейс.
  /// - Parameters:
  ///   - translator: движок перевода.
  ///   - languageDetector: определитель языка исходного текста.
  public init(translator: any TextTranslating, languageDetector: any LanguageDetecting) {
    self.translator = translator
    self.languageDetector = languageDetector
  }

  /// Переводит текст, отменив предыдущий незавершённый запрос.
  /// - Parameters:
  ///   - text: исходный текст.
  ///   - source: исходный язык; `nil` — определить автоматически.
  ///   - target: язык перевода.
  /// - Returns: исход перевода; `.cancelled`, если запрос вытеснен более свежим.
  public func callAsFunction(
    _ text: String,
    from source: Language? = nil,
    to target: Language
  ) async -> TranslationOutcome {
    inFlight?.cancel()

    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      inFlight = nil
      return .empty
    }

    let resolvedSource = source ?? languageDetector.language(of: trimmed)
    let task = Task { [translator] () -> TranslationOutcome in
      let outcome = await translator.translate(trimmed, from: resolvedSource, to: target)
      return Task.isCancelled ? .cancelled : outcome
    }
    inFlight = task
    return await task.value
  }
}
