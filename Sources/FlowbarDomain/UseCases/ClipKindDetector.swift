import Foundation

/// Правило определения вида копии.
///
/// Девятый вид — это новое правило и строка в списке, а не ещё одна ветка в `switch`.
public protocol ClipKindRule: Sendable {

  /// Определяет вид содержимого.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`, если правило не сработало.
  func kind(for item: PasteboardItem) -> ClipKind?
}

/// Определитель вида копии: цепочка правил, первое совпадение выигрывает.
public struct ClipKindDetector: Sendable {

  /// Порядок правил из спеки §8.1 с одной вставкой.
  ///
  /// `ValueRule` стоит перед `CodeRule`, потому что хеш, скопированный из терминала,
  /// иначе классифицируется как код: `CodeRule` смотрит на приложение-источник, а терминал
  /// в списке редакторов. В макете такая строка помечена как «Значение».
  ///
  /// Спека объявляет восемь видов, но описывает семь правил — для `value` правила нет.
  /// `ValueRule` закрывает эту дыру: без него критерий приёмки «тип определяется верно для
  /// восьми видов» невыполним.
  ///
  /// `EmailRule` — девятый вид, заведённый по факту использования: в истории копирований
  /// адреса почты оказались заметной долей и лежали с иконкой цепочки, потому что
  /// `NSDataDetector` считает их ссылками.
  public static let defaultRules: [any ClipKindRule] = [
    FilePathRule(),
    ImageRule(),
    EmailRule(),
    LinkRule(),
    ColorRule(),
    AddressRule(),
    ValueRule(),
    CodeRule(),
  ]

  private let rules: [any ClipKindRule]

  /// Создаёт определитель.
  /// - Parameter rules: правила в порядке применения.
  public init(rules: [any ClipKindRule] = ClipKindDetector.defaultRules) {
    self.rules = rules
  }

  /// Определяет вид содержимого.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид; `.text`, если не сработало ни одно правило.
  public func detect(_ item: PasteboardItem) -> ClipKind {
    rules.lazy.compactMap { $0.kind(for: item) }.first ?? .text
  }
}
