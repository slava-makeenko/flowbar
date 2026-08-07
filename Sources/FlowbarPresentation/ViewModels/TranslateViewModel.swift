import FlowbarDomain
import Foundation

/// Экран перевода.
@MainActor
@Observable
public final class TranslateViewModel {

  /// Состояние перевода, показываемое в шапке правой панели.
  public enum Status: Equatable, Sendable {

    /// Вводить ещё нечего.
    case waitingForInput

    /// Пользователь печатает, отсчёт до запроса идёт.
    case typing

    /// Запрос выполняется.
    case working

    /// Перевод получен.
    case done

    /// Языковой пакет недоступен.
    case unavailable

    /// Подпись для интерфейса.
    public var title: String {
      switch self {
      case .waitingForInput: "ожидание ввода"
      case .typing: "печатаю…"
      case .working: "перевод…"
      case .done: "готово"
      case .unavailable: "язык не загружен"
      }
    }
  }

  /// Пауза после последнего нажатия клавиши перед запросом.
  public static let debounce: Duration = .milliseconds(700)

  /// Предел длины исходного текста.
  public static let inputLimit = 2000

  /// Исходный текст.
  public var sourceText: String = "" {
    didSet { scheduleTranslation() }
  }

  /// Исходный язык; `nil` — определять автоматически.
  public var sourceLanguage: Language? {
    didSet { runNow() }
  }

  /// Язык перевода.
  public var targetLanguage: Language {
    didSet { runNow() }
  }

  /// Переведённый текст.
  public private(set) var translatedText = ""

  /// Текущее состояние.
  public private(set) var status: Status = .waitingForInput

  /// Язык, определённый по исходному тексту.
  public private(set) var detectedLanguage: Language?

  private let translate: TranslateText
  private let languageDetector: any LanguageDetecting
  private let pasteboard: any PasteboardWriting
  private let feedback: CopyFeedback

  private var debounceTask: Task<Void, Never>?

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - translate: юзкейс перевода с отменой предыдущего запроса.
  ///   - languageDetector: определитель языка.
  ///   - pasteboard: запись в пастборд.
  ///   - feedback: подтверждение копирования.
  ///   - sourceLanguage: исходный язык по умолчанию.
  ///   - targetLanguage: язык перевода по умолчанию.
  public init(
    translate: TranslateText,
    languageDetector: any LanguageDetecting,
    pasteboard: any PasteboardWriting,
    feedback: CopyFeedback,
    sourceLanguage: Language? = nil,
    targetLanguage: Language = Language(code: "en")
  ) {
    self.translate = translate
    self.languageDetector = languageDetector
    self.pasteboard = pasteboard
    self.feedback = feedback
    self.sourceLanguage = sourceLanguage
    self.targetLanguage = targetLanguage
  }

  /// Меняет языки местами вместе с содержимым полей.
  public func swapLanguages() {
    let previousSource = sourceLanguage ?? detectedLanguage
    let previousText = sourceText

    sourceLanguage = targetLanguage
    if let previousSource { targetLanguage = previousSource }
    sourceText = translatedText.isEmpty ? previousText : translatedText
  }

  /// Очищает оба поля.
  public func clear() {
    debounceTask?.cancel()
    sourceText = ""
    translatedText = ""
    detectedLanguage = nil
    status = .waitingForInput
  }

  /// Кладёт перевод в пастборд.
  public func copyTranslation() async {
    guard !translatedText.isEmpty else { return }
    await pasteboard.write(text: translatedText)
    feedback.confirm("Перевод скопирован", item: "translation")
  }

  // MARK: - Запуск перевода

  private func scheduleTranslation() {
    debounceTask?.cancel()

    guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      translatedText = ""
      detectedLanguage = nil
      status = .waitingForInput
      return
    }

    status = .typing
    debounceTask = Task { [weak self] in
      try? await Task.sleep(for: Self.debounce)
      guard !Task.isCancelled else { return }
      await self?.run()
    }
  }

  private func runNow() {
    debounceTask?.cancel()
    guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    debounceTask = Task { [weak self] in await self?.run() }
  }

  private func run() async {
    detectedLanguage = languageDetector.language(of: sourceText)
    status = .working

    switch await translate(sourceText, from: sourceLanguage, to: targetLanguage) {
    case .translated(let result):
      translatedText = result
      status = .done
    case .unavailable:
      translatedText = ""
      status = .unavailable
    case .empty:
      translatedText = ""
      status = .waitingForInput
    case .cancelled:
      break
    }
  }
}
