import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

private let english = Language(code: "en")

@Test("Пустой ввод не доходит до движка перевода")
func emptyInputSkipsEngine() async {
  let translator = FakeTranslator()
  let useCase = TranslateText(translator: translator, languageDetector: FakeLanguageDetector())

  let outcome = await useCase("   ", to: english)

  #expect(outcome == .empty)
  #expect(await translator.requests.isEmpty)
}

@Test("Недоступный языковой пакет даёт штатный исход, а не ошибку")
func unavailableLanguagePackIsNotAnError() async {
  let translator = FakeTranslator(outcome: .unavailable)
  let useCase = TranslateText(translator: translator, languageDetector: FakeLanguageDetector())

  #expect(await useCase("привет", to: english) == .unavailable)
}

@Test("Быстрый повторный ввод отменяет предыдущий запрос")
func rapidInputCancelsPreviousRequest() async {
  let translator = FakeTranslator(outcome: .translated("hello"), holdsAnswers: true)
  let useCase = TranslateText(translator: translator, languageDetector: FakeLanguageDetector())

  async let first = useCase("привет", to: english)
  await translator.waitForRequests(1)

  async let second = useCase("привет мир", to: english)
  await translator.waitForRequests(2)

  await translator.answerHeldRequests()
  let firstOutcome = await first
  let secondOutcome = await second

  #expect(firstOutcome == .cancelled)
  #expect(secondOutcome == .translated("hello"))
}

@Test("Определённый язык уходит в движок как исходный")
func detectedLanguageIsPassedThrough() async {
  let translator = FakeTranslator()
  let detector = FakeLanguageDetector(answer: Language(code: "ru"))
  let useCase = TranslateText(translator: translator, languageDetector: detector)

  _ = await useCase("привет", to: english)

  #expect(await translator.requests == ["привет"])
}

@Test("Текст обрезается по краям перед переводом")
func trimsInputBeforeTranslating() async {
  let translator = FakeTranslator()
  let useCase = TranslateText(translator: translator, languageDetector: FakeLanguageDetector())

  _ = await useCase("  привет  ", to: english)

  #expect(await translator.requests == ["привет"])
}
