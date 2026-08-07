import FlowbarDomain
import Foundation

extension Language {

  /// Языки, доступные в селекторах переводчика.
  public static let offered: [Language] = [
    Language(code: "ru"),
    Language(code: "en"),
    Language(code: "de"),
    Language(code: "fr"),
    Language(code: "es"),
    Language(code: "it"),
    Language(code: "zh"),
    Language(code: "ja"),
  ]

  /// Название языка на языке интерфейса.
  public var title: String {
    InterfaceLocale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
  }
}
