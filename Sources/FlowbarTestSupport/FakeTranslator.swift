import FlowbarDomain
import Foundation

/// Переводчик-фейк с ручным управлением моментом ответа.
///
/// Задержка ответа нужна, чтобы отмену устаревшего запроса можно было проверить без
/// `Task.sleep`: тест дожидается, что запрос дошёл, шлёт следующий и только потом
/// отпускает оба.
public actor FakeTranslator: TextTranslating {

  /// Тексты запросов в порядке поступления.
  public private(set) var requests: [String] = []

  private let outcome: TranslationOutcome
  private let holdsAnswers: Bool
  private var held: [CheckedContinuation<Void, Never>] = []
  private var observers: [CheckedContinuation<Void, Never>] = []

  /// Создаёт переводчик.
  /// - Parameters:
  ///   - outcome: что отдавать в ответ на любой запрос.
  ///   - holdsAnswers: задерживать ли ответ до вызова `answerHeldRequests()`.
  public init(outcome: TranslationOutcome = .translated("готово"), holdsAnswers: Bool = false) {
    self.outcome = outcome
    self.holdsAnswers = holdsAnswers
  }

  /// Записывает запрос и отдаёт заранее заданный исход.
  /// - Parameters:
  ///   - text: исходный текст.
  ///   - source: исходный язык, не используется.
  ///   - target: язык перевода, не используется.
  /// - Returns: исход, заданный при создании.
  public func translate(_ text: String, from source: Language?, to target: Language) async
    -> TranslationOutcome
  {
    requests.append(text)
    resumeObservers()
    if holdsAnswers {
      await withCheckedContinuation { held.append($0) }
    }
    return outcome
  }

  /// Ждёт, пока число полученных запросов не достигнет указанного.
  /// - Parameter count: ожидаемое число запросов.
  public func waitForRequests(_ count: Int) async {
    while requests.count < count {
      await withCheckedContinuation { observers.append($0) }
    }
  }

  /// Отвечает на все задержанные запросы.
  public func answerHeldRequests() {
    let waiting = held
    held.removeAll()
    for continuation in waiting { continuation.resume() }
  }

  private func resumeObservers() {
    let waiting = observers
    observers.removeAll()
    for continuation in waiting { continuation.resume() }
  }
}

/// Определитель языка с заранее заданным ответом.
public struct FakeLanguageDetector: LanguageDetecting {

  private let answer: Language?

  /// Создаёт определитель.
  /// - Parameter answer: язык, который возвращается для любого текста.
  public init(answer: Language? = nil) {
    self.answer = answer
  }

  /// Отдаёт язык, заданный при создании.
  /// - Parameter text: текст, не используется.
  /// - Returns: заданный язык или `nil`.
  public func language(of text: String) -> Language? { answer }
}
