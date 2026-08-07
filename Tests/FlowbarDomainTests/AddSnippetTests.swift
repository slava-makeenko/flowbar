import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

/// Один вход таблицы валидации из спеки §8.5.
struct SnippetSample: Sendable, CustomStringConvertible {

  let description: String
  let kind: SnippetKind
  let input: String
  let expected: Result<String, SnippetRejection>

  static let all: [SnippetSample] = [
    SnippetSample(
      description: "почта нормализуется обрезкой пробелов",
      kind: .email, input: "  hey@flowbar.app  ", expected: .success("hey@flowbar.app")
    ),
    SnippetSample(
      description: "почта без домена отвергается",
      kind: .email, input: "hey@flowbar", expected: .failure(.malformedEmail)
    ),
    SnippetSample(
      description: "почта с пробелом внутри отвергается",
      kind: .email, input: "hey there@flowbar.app", expected: .failure(.malformedEmail)
    ),
    SnippetSample(
      description: "тегу дописывается решётка",
      kind: .tag, input: "design-review", expected: .success("#design-review")
    ),
    SnippetSample(
      description: "тег с решёткой не трогается",
      kind: .tag, input: "#design-review", expected: .success("#design-review")
    ),
    SnippetSample(
      description: "тег с собакой не трогается",
      kind: .tag, input: "@slava", expected: .success("@slava")
    ),
    SnippetSample(
      description: "тег с пробелом отвергается",
      kind: .tag, input: "design review", expected: .failure(.tagContainsWhitespace)
    ),
    SnippetSample(
      description: "тег из одного символа отвергается",
      kind: .tag, input: "a", expected: .failure(.tagTooShort)
    ),
    SnippetSample(
      description: "в номере схлопываются пробелы",
      kind: .phone, input: "+7  900   000-00-00", expected: .success("+7 900 000-00-00")
    ),
    SnippetSample(
      description: "буквы в номере отвергаются",
      kind: .phone, input: "+7 900 ABC-00-00", expected: .failure(.malformedPhone)
    ),
    SnippetSample(
      description: "слишком короткий номер отвергается",
      kind: .phone, input: "+7 90", expected: .failure(.malformedPhone)
    ),
    SnippetSample(
      description: "пустое значение отвергается",
      kind: .email, input: "   ", expected: .failure(.empty)
    ),
  ]
}

@Test("Валидация и нормализация по таблице спеки §8.5", arguments: SnippetSample.all)
func validatesByTable(sample: SnippetSample) async {
  let addSnippet = AddSnippet(store: FakeSnippetStore())

  let result = await addSnippet(kind: sample.kind, value: sample.input)

  switch (result, sample.expected) {
  case (.success(let snippet), .success(let expected)):
    #expect(snippet.value == expected, "\(sample.description)")
  case (.failure(let rejection), .failure(let expected)):
    #expect(rejection == expected, "\(sample.description)")
  default:
    Issue.record("\(sample.description): получили \(result), ждали \(sample.expected)")
  }
}

@Test("Дубликат отклоняется без учёта регистра")
func rejectsDuplicateIgnoringCase() async {
  let existing = Snippet(id: UUID(), kind: .email, value: "hey@flowbar.app")
  let store = FakeSnippetStore(snippets: [existing])
  let addSnippet = AddSnippet(store: store)

  let result = await addSnippet(kind: .email, value: "HEY@Flowbar.App")

  #expect(result == .failure(.duplicate))
  #expect(await store.snippets.count == 1)
}

@Test("Одинаковое значение разных видов дубликатом не считается")
func allowsSameValueForDifferentKind() async {
  let existing = Snippet(id: UUID(), kind: .tag, value: "#12345678")
  let store = FakeSnippetStore(snippets: [existing])
  let addSnippet = AddSnippet(store: store)

  let result = await addSnippet(kind: .phone, value: "#12345678")

  #expect(result == .failure(.malformedPhone))
}

@Test("Новая вставка встаёт в начало списка")
func insertsAtHead() async {
  let existing = Snippet(id: UUID(), kind: .tag, value: "#старая")
  let store = FakeSnippetStore(snippets: [existing])
  let addSnippet = AddSnippet(store: store)

  _ = await addSnippet(kind: .email, value: "hey@flowbar.app")

  let values = await store.snippets.map(\.value)
  #expect(values == ["hey@flowbar.app", "#старая"])
}

@Test("Подпись сохраняется как есть")
func keepsNote() async {
  let addSnippet = AddSnippet(store: FakeSnippetStore())

  let result = await addSnippet(kind: .email, value: "hey@flowbar.app", note: "рабочая")

  #expect((try? result.get())?.note == "рабочая")
}
