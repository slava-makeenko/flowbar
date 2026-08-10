import Foundation

/// Файл в пастборде — путь.
public struct FilePathRule: ClipKindRule {

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.path`, если в пастборде лежит ссылка на файл.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    item.fileURL == nil ? nil : .path
  }
}

/// Растр в пастборде — изображение.
public struct ImageRule: ClipKindRule {

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.image`, если в пастборде лежит растр.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    item.imageData == nil ? nil : .image
  }
}

/// Строка целиком распознаётся как адрес электронной почты.
///
/// Стоит **до** `LinkRule`: `NSDataDetector` считает адрес почты ссылкой, и без этого
/// правила `slava@example.com` попадал бы в историю с иконкой цепочки.
public struct EmailRule: ClipKindRule {

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.email` для строки вида `name@example.com`.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    guard let text = item.text?.trimmed(), !text.isEmpty else { return nil }
    return text.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil ? .email : nil
  }
}

/// Строка целиком распознаётся как ссылка.
public struct LinkRule: ClipKindRule {

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.link`, если `NSDataDetector` покрывает ссылкой всю строку.
  ///
  /// Совпадение по части строки не годится: «пиши на support@flowbar.app» — это текст,
  /// а не ссылка.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    TextChecking.matchesEntirely(item.text, type: .link) ? .link : nil
  }
}

/// Строка целиком распознаётся как почтовый адрес.
public struct AddressRule: ClipKindRule {

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.address`, если `NSDataDetector` покрывает адресом всю строку.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    TextChecking.matchesEntirely(item.text, type: .address) ? .address : nil
  }
}

/// Цвет в записи hex, `rgb()`, `hsl()` или `oklch()`.
public struct ColorRule: ClipKindRule {

  private static let functions = ["rgb(", "rgba(", "hsl(", "hsla(", "oklch(", "oklab("]

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.color` для hex-записи длиной 3–8 символов или вызова цветовой функции.
  ///
  /// Регулярное выражение спеки §8.1 воспроизведено как есть. Оно ловит и заведомо
  /// не-цвета вроде «12345678», но спека прямо разрешает промахи: вид влияет на иконку.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    guard let text = item.text?.trimmed(), !text.isEmpty else { return nil }

    let lowercased = text.lowercased()
    if Self.functions.contains(where: lowercased.hasPrefix) { return .color }

    let hex = lowercased.hasPrefix("#") ? String(lowercased.dropFirst()) : lowercased
    guard (3...8).contains(hex.count) else { return nil }
    return hex.allSatisfy(\.isHexDigit) ? .color : nil
  }
}

/// Идентификатор, хеш или токен: строка без пробелов, читаемая как значение.
///
/// Правила в спеке нет — обоснование в `ClipKindDetector.defaultRules`.
public struct ValueRule: ClipKindRule {

  private static let allowed = Set("0123456789abcdefghijklmnopqrstuvwxyz_.:+/=-")
  private static let minimumLength = 8

  /// Создаёт правило.
  public init() {}

  /// Отдаёт `.value` для строки от восьми символов без пробелов, содержащей цифру.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    guard let text = item.text?.trimmed(), text.count >= Self.minimumLength else { return nil }
    guard text.lowercased().allSatisfy(Self.allowed.contains) else { return nil }
    guard text.contains(where: \.isNumber) else { return nil }
    return .value
  }
}

/// Признаки исходного кода: разделители, отступы или приложение-редактор.
public struct CodeRule: ClipKindRule {

  /// Приложения, из которых копируют преимущественно код.
  public static let defaultEditorBundleIdentifiers: Set<String> = [
    "com.apple.dt.Xcode",
    "com.microsoft.VSCode",
    "com.todesktop.230313mzl4w4u92",  // Cursor
    "com.jetbrains.intellij",
    "com.jetbrains.AppCode",
    "com.sublimetext.4",
    "com.apple.Terminal",
    "com.googlecode.iterm2",
  ]

  private static let markers = ["{", "}", ";", "=>"]

  private let editorBundleIdentifiers: Set<String>

  /// Создаёт правило.
  /// - Parameter editorBundleIdentifiers: приложения, считающиеся редакторами кода.
  public init(
    editorBundleIdentifiers: Set<String> = CodeRule.defaultEditorBundleIdentifiers
  ) {
    self.editorBundleIdentifiers = editorBundleIdentifiers
  }

  /// Отдаёт `.code` по приложению-источнику, разделителям или отступам.
  ///
  /// Самое неточное правило цепочки, и это заложено спекой §8.1: ошибка меняет иконку,
  /// а не поведение.
  /// - Parameter item: снимок пастборда.
  /// - Returns: вид или `nil`.
  public func kind(for item: PasteboardItem) -> ClipKind? {
    guard let text = item.text, !text.trimmed().isEmpty else { return nil }

    if let bundle = item.sourceApp.bundleIdentifier, editorBundleIdentifiers.contains(bundle) {
      return .code
    }
    if Self.markers.contains(where: text.contains) { return .code }

    let indented = text.split(separator: "\n").contains {
      $0.hasPrefix("  ") || $0.hasPrefix("\t")
    }
    return indented ? .code : nil
  }
}

// MARK: - Общее

/// Обёртка над `NSDataDetector` для правил, которым нужно совпадение по всей строке.
private enum TextChecking {

  static func matchesEntirely(_ text: String?, type: NSTextCheckingResult.CheckingType) -> Bool {
    guard let text = text?.trimmed(), !text.isEmpty else { return false }
    guard let detector = try? NSDataDetector(types: type.rawValue) else { return false }

    let range = NSRange(text.startIndex..., in: text)
    guard let match = detector.firstMatch(in: text, range: range) else { return false }
    return match.range == range
  }
}

extension String {

  fileprivate func trimmed() -> String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
