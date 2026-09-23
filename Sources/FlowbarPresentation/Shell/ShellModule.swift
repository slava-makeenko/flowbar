import Foundation

/// Модуль панели — пункт бокового рейла.
public enum ShellModule: String, CaseIterable, Identifiable, Sendable {

  /// История копирований.
  case clipboard

  /// Лента снимков экрана.
  case screenshots

  /// Переводчик.
  case translate

  /// Быстрые вставки.
  case snippets

  /// Лимиты Claude Code и Codex.
  case limits

  /// Настройки приложения.
  case settings

  /// Пункты основной группы рейла.
  ///
  /// Настройки в неё не входят: они прижаты к низу рейла отдельно, как в макете.
  public static let modules: [ShellModule] = [
    .clipboard, .screenshots, .translate, .snippets, .limits,
  ]

  /// Идентификатор для списков.
  public var id: String { rawValue }

  /// Название модуля. Оно же метка для VoiceOver.
  public var title: String {
    switch self {
    case .clipboard: "Буфер"
    case .screenshots: "Снимки"
    case .translate: "Перевод"
    case .snippets: "Вставки"
    case .limits: "Лимиты"
    case .settings: "Настройки"
    }
  }

  /// Глобальное сочетание, открывающее модуль, если оно есть.
  public var shortcut: String? {
    switch self {
    case .clipboard: "⌘⇧V"
    case .translate: "⌥T"
    case .screenshots, .snippets, .limits, .settings: nil
    }
  }
}
