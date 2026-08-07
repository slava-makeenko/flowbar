import FlowbarDomain
import Foundation

/// Экран быстрых вставок.
@MainActor
@Observable
public final class SnippetsViewModel {

  /// Список вставок, свежие первыми.
  public private(set) var snippets: [Snippet] = []

  /// Выбранный вид в форме добавления.
  public var draftKind: SnippetKind = .email {
    didSet { errorMessage = nil }
  }

  /// Введённое значение.
  public var draftValue: String = "" {
    didSet { errorMessage = nil }
  }

  /// Сообщение об ошибке под формой; `nil`, когда ошибок нет.
  public private(set) var errorMessage: String?

  private let store: any SnippetStoring
  private let addSnippet: AddSnippet
  private let pasteboard: any PasteboardWriting
  private let feedback: CopyFeedback

  /// Создаёт вью-модель.
  /// - Parameters:
  ///   - store: хранилище вставок.
  ///   - addSnippet: добавление с валидацией.
  ///   - pasteboard: запись в пастборд.
  ///   - feedback: подтверждение копирования.
  public init(
    store: any SnippetStoring,
    addSnippet: AddSnippet,
    pasteboard: any PasteboardWriting,
    feedback: CopyFeedback
  ) {
    self.store = store
    self.addSnippet = addSnippet
    self.pasteboard = pasteboard
    self.feedback = feedback
  }

  /// Идентификатор вставки, чья кнопка копирования сейчас показывает галочку.
  public var confirmingItem: String? { feedback.confirmingItem }

  /// Плейсхолдер поля меняется вместе с выбранным видом.
  public var placeholder: String {
    switch draftKind {
    case .email: "name@example.com"
    case .tag: "#design-review"
    case .phone: "+7 900 000-00-00"
    }
  }

  /// Читает список из хранилища.
  public func load() async {
    snippets = await store.all()
  }

  /// Добавляет вставку из формы.
  public func add() async {
    switch await addSnippet(kind: draftKind, value: draftValue) {
    case .success:
      draftValue = ""
      errorMessage = nil
      snippets = await store.all()
    case .failure(let rejection):
      errorMessage = Self.message(for: rejection, kind: draftKind)
    }
  }

  /// Кладёт значение вставки в пастборд.
  /// - Parameter snippet: вставка.
  public func copy(_ snippet: Snippet) async {
    await pasteboard.write(text: snippet.value)
    feedback.confirm("Скопировано в буфер", item: snippet.id.uuidString)
  }

  /// Удаляет вставку.
  /// - Parameter snippet: вставка.
  public func remove(_ snippet: Snippet) async {
    let remaining = snippets.filter { $0.id != snippet.id }
    await store.replaceAll(with: remaining)
    snippets = remaining
  }

  /// Формулировки из спеки §8.5. Домен сообщает, что не так, а слово подбирается здесь.
  private static func message(for rejection: SnippetRejection, kind: SnippetKind) -> String {
    switch rejection {
    case .empty:
      "Сначала введите значение"
    case .malformedEmail:
      "Похоже, это не адрес почты — нужен формат name@example.com"
    case .tagContainsWhitespace:
      "Тег не должен содержать пробелов"
    case .tagTooShort:
      "Тег слишком короткий"
    case .malformedPhone:
      "В номере допустимы только цифры, пробелы, «+», «(» и «-»"
    case .duplicate:
      "Такая вставка уже есть в списке"
    }
  }
}
