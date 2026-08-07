import FlowbarDomain
import Foundation
import NaturalLanguage

/// Определение языка текста средствами `NaturalLanguage`.
public struct NLLanguageDetector: LanguageDetecting {

  /// Создаёт определитель.
  public init() {}

  /// Определяет преобладающий язык текста.
  /// - Parameter text: текст.
  /// - Returns: язык или `nil`, если уверенности нет.
  public func language(of text: String) -> Language? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let dominant = recognizer.dominantLanguage else { return nil }
    return Language(code: dominant.rawValue)
  }
}
