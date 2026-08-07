import AppKit
import CoreText
import SwiftUI

/// Именованный стиль текста: размер, вес и трекинг.
public struct TypeStyle: Equatable, Sendable {

  /// Кегль в пунктах.
  public let size: CGFloat

  /// Вес по оси `wght`: 400, 510 или 590.
  public let weight: CGFloat

  /// Трекинг в долях кегля, как в макете.
  public let trackingEm: CGFloat

  /// Моноширинный ли стиль.
  public let isMonospaced: Bool

  /// Создаёт стиль.
  /// - Parameters:
  ///   - size: кегль в пунктах.
  ///   - weight: вес по оси `wght`.
  ///   - trackingEm: трекинг в долях кегля.
  ///   - isMonospaced: моноширинный ли стиль.
  public init(
    size: CGFloat,
    weight: CGFloat,
    trackingEm: CGFloat = 0,
    isMonospaced: Bool = false
  ) {
    self.size = size
    self.weight = weight
    self.trackingEm = trackingEm
    self.isMonospaced = isMonospaced
  }

  /// Трекинг в пунктах — то, что принимает SwiftUI.
  public var tracking: CGFloat { trackingEm * size }
}

extension TypeStyle {

  /// Название трека в плеере.
  public static let trackTitle = TypeStyle(size: 22, weight: 590, trackingEm: -0.02)

  /// Селектор языка в переводчике.
  public static let language = TypeStyle(size: 13, weight: 590, trackingEm: -0.01)

  /// Поле ввода переводчика.
  public static let translationField = TypeStyle(size: 16, weight: 400)

  /// Строка списка: история копирований и быстрые вставки.
  public static let listRow = TypeStyle(size: 13, weight: 510)

  /// Имя файла на карточке скриншота.
  public static let cardTitle = TypeStyle(size: 12, weight: 510)

  /// Метаданные под строкой списка.
  public static let metadata = TypeStyle(size: 11, weight: 400)

  /// Подписи и чипы.
  public static let caption = TypeStyle(size: 11, weight: 510)

  /// Мелкие подписи: время, размеры.
  public static let captionSmall = TypeStyle(size: 10, weight: 400)

  /// Надзаголовок прописными.
  ///
  /// Положительный трекинг обязателен: прописные без него — самая заметная ошибка вёрстки.
  public static let overline = TypeStyle(size: 10, weight: 400, trackingEm: 0.08)

  /// Текст кнопки.
  public static let button = TypeStyle(size: 12, weight: 590, trackingEm: 0.01)

  /// Моноширинный чип шортката.
  public static let keyChip = TypeStyle(size: 11, weight: 400, isMonospaced: true)

  /// Моноширинные мелкие подписи: время трека, размер файла.
  public static let monoCaption = TypeStyle(size: 10, weight: 400, isMonospaced: true)
}

/// Гарнитуры интерфейса.
///
/// Inter нужен именно с фичами `cv01` и `ss03` — без них получается обычный Inter, а не тот
/// рисунок, что в макете. В SF Pro этих фич нет, подменить нельзя.
public enum Typography {

  /// Ось веса `wght` в вариативном шрифте.
  private static let weightAxis = 0x7767_6874

  /// Доступен ли забандленный Inter.
  ///
  /// Если `false`, интерфейс наберётся системным шрифтом: сборка не падает, но макет
  /// воспроизведён не будет. Проверяется в чеклисте приёмки фазы 2.
  public static var isInterAvailable: Bool { resolvedInterFamily != nil }

  /// Имя семейства, которым фактически набирается интерфейс.
  public static var resolvedFamilyName: String { resolvedInterFamily ?? "система" }

  /// Шрифт SwiftUI для стиля.
  /// - Parameter style: именованный стиль.
  /// - Returns: шрифт.
  public static func font(_ style: TypeStyle) -> Font {
    Font(nsFont(style))
  }

  /// Шрифт AppKit для стиля.
  /// - Parameter style: именованный стиль.
  /// - Returns: шрифт.
  public static func nsFont(_ style: TypeStyle) -> NSFont {
    if style.isMonospaced {
      return .monospacedSystemFont(ofSize: style.size, weight: systemWeight(style.weight))
    }
    guard let family = resolvedInterFamily else {
      return .systemFont(ofSize: style.size, weight: systemWeight(style.weight))
    }

    let descriptor = NSFontDescriptor(
      fontAttributes: [
        .family: family,
        kCTFontVariationAttribute as NSFontDescriptor.AttributeName: [weightAxis: style.weight],
        // Через строковый тег, а не через числовой идентификатор фичи: спека §5
        // предупреждает, что второй путь на Core Text работает не всегда.
        kCTFontFeatureSettingsAttribute as NSFontDescriptor.AttributeName: [
          [kCTFontOpenTypeFeatureTag as String: "cv01", kCTFontOpenTypeFeatureValue as String: 1],
          [kCTFontOpenTypeFeatureTag as String: "ss03", kCTFontOpenTypeFeatureValue as String: 1],
        ],
      ]
    )
    return NSFont(descriptor: descriptor, size: style.size)
      ?? .systemFont(ofSize: style.size, weight: systemWeight(style.weight))
  }

  private static func systemWeight(_ weight: CGFloat) -> NSFont.Weight {
    switch weight {
    case ..<450: .regular
    case ..<550: .medium
    default: .semibold
    }
  }
}

/// Имя семейства Inter, найденное среди установленных шрифтов.
///
/// Кандидатов несколько, потому что имя семейства менялось между выпусками Inter:
/// `Inter Variable` в свежих, `InterVariable` и `Inter` в более ранних. Промах по имени
/// проявляется молча — интерфейс просто набирается системным шрифтом, поэтому перебор
/// дешевле одной потерянной сессии отладки.
private let resolvedInterFamily: String? = {
  let candidates = ["InterVariable", "Inter Variable", "Inter"]
  let installed = Set(NSFontManager.shared.availableFontFamilies)
  return candidates.first { installed.contains($0) }
}()

extension View {

  /// Применяет именованный стиль текста.
  /// - Parameter style: стиль.
  /// - Returns: вью с применённым шрифтом и трекингом.
  public func typeStyle(_ style: TypeStyle) -> some View {
    font(Typography.font(style)).tracking(style.tracking)
  }
}
