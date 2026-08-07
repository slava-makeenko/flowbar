import Foundation

/// Модуль панели — пункт бокового рейла.
public enum ShellModule: String, CaseIterable, Identifiable, Sendable {

  /// История копирований.
  case clipboard

  /// Лента снимков экрана.
  case screenshots

  /// Переводчик.
  case translate

  /// Плеер системного аудио.
  case music

  /// Быстрые вставки.
  case snippets

  /// Идентификатор для списков.
  public var id: String { rawValue }

  /// Название модуля. Оно же метка для VoiceOver.
  public var title: String {
    switch self {
    case .clipboard: "Буфер"
    case .screenshots: "Снимки"
    case .translate: "Перевод"
    case .music: "Музыка"
    case .snippets: "Вставки"
    }
  }

  /// Глобальное сочетание, открывающее модуль, если оно есть.
  public var shortcut: String? {
    switch self {
    case .clipboard: "⌘⇧V"
    case .translate: "⌥T"
    case .screenshots, .music, .snippets: nil
    }
  }
}
