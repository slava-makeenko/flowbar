import SwiftUI

/// Цвета интерфейса.
///
/// Единственное место в проекте, где встречаются литералы цвета. Значения сняты из `:root`
/// прототипа один в один.
public enum Palette {

  // MARK: - Поверхности

  /// Корпус панели на экранах без выреза.
  public static let bg = Color(hex: 0x0809_0A)

  /// Корпус панели на экране с вырезом.
  ///
  /// Чистый чёрный, а не `bg`: вырез шире пилюли не бывает, стык приходится на видимую
  /// зону, и одна ступень яркости читается как шов. Обоснование и замер — ADR-0004.
  public static let bgNotched = Color.black

  /// Приподнятая поверхность: подсказки, тост.
  public static let surface = Color(hex: 0x191A_1B)

  // MARK: - Текст

  /// Основной текст.
  public static let fg = Color(hex: 0xF7F8_F8)

  /// Вторичный текст.
  public static let fg2 = Color(hex: 0xD0D6_E0)

  /// Метаданные, плейсхолдеры, иконки в покое.
  ///
  /// Токен `--meta` (`#62666d`) из макета сюда не переносится: он даёт 1.99:1 на чёрном.
  /// В текстовых стилях его быть не должно.
  public static let muted = Color(hex: 0x8A8F_98)

  // MARK: - Границы

  /// Обычная граница.
  public static let border = Color.white.opacity(0.08)

  /// Едва заметный разделитель.
  public static let borderSoft = Color.white.opacity(0.05)

  /// Обычная граница при включённом Increase Contrast.
  public static let borderIncreasedContrast = Color.white.opacity(0.20)

  /// Разделитель при включённом Increase Contrast.
  public static let borderSoftIncreasedContrast = Color.white.opacity(0.12)

  /// Обычная граница с учётом системной настройки контраста.
  /// - Parameter increasedContrast: включён ли Increase Contrast.
  /// - Returns: подходящий цвет границы.
  public static func border(increasedContrast: Bool) -> Color {
    increasedContrast ? borderIncreasedContrast : border
  }

  /// Разделитель с учётом системной настройки контраста.
  /// - Parameter increasedContrast: включён ли Increase Contrast.
  /// - Returns: подходящий цвет разделителя.
  public static func borderSoft(increasedContrast: Bool) -> Color {
    increasedContrast ? borderSoftIncreasedContrast : borderSoft
  }

  /// Глазок камеры в пилюле.
  public static let lens = Color.white.opacity(0.22)

  // MARK: - Акцент

  /// Акцент. Только для primary-кнопки.
  public static let accent = Color(hex: 0x5E6A_D2)

  /// Текст на акцентной заливке.
  public static let accentOn = Color.white

  /// Осветлённый акцент: активный пункт рейла и hover primary-кнопки.
  public static let accentHover = Color(hex: 0x828F_FF)

  /// Затемнённый акцент: нажатая primary-кнопка.
  public static let accentPressed = Color(hex: 0x4752_C4)

  // MARK: - Семантика

  /// Подтверждение: рамка скопированной карточки, галочка.
  public static let success = Color(hex: 0x27A6_44)

  /// Ошибка: рамка невалидного поля, удаление.
  public static let danger = Color(hex: 0xDC26_26)
}

/// Заливки состояний.
///
/// Глубина на чёрном строится ступенями белой прозрачности, а не тенями. Правило контраста:
/// при смене состояния меняется только фон — текст и иконки не темнеют никогда.
public enum Fill {

  /// Покой карточки или строки.
  public static let rest = Color.clear

  /// Наведение на строку списка.
  public static let rowHover = Color.white.opacity(0.05)

  /// Наведение на иконочную кнопку.
  public static let iconButtonHover = Color.white.opacity(0.09)

  /// Наведение на кнопку рейла.
  public static let railButtonHover = Color.white.opacity(0.07)

  /// Активный пункт рейла.
  public static let railButtonSelected = Color.white.opacity(0.05)

  /// Наведение на карточку скриншота.
  public static let cardHover = Color.white.opacity(0.06)

  /// Нажатие.
  public static let pressed = Color.white.opacity(0.10)

  /// Подложка иконки типа в строке списка.
  public static let typeBadge = Color.white.opacity(0.06)

  /// Поле ввода в покое.
  public static let fieldRest = Color.white.opacity(0.03)

  /// Поле ввода с фокусом внутри.
  public static let fieldFocused = Color.white.opacity(0.06)

  /// Выбранный сегмент переключателя.
  public static let segmentSelected = Color.white.opacity(0.10)

  /// Дорожка ползунка.
  public static let sliderTrack = Color.white.opacity(0.12)

  /// Ползунок полосы прокрутки.
  public static let scrollThumb = Color.white.opacity(0.12)
}

extension Color {

  /// Создаёт цвет из шестнадцатеричного значения `0xRRGGBB`.
  /// - Parameter hex: значение вида `0x5E6AD2`.
  public init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1
    )
  }
}
