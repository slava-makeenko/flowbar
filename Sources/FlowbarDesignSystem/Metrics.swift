import CoreGraphics

/// Геометрия интерфейса.
///
/// Единственное место в проекте, где встречаются литералы размера. Значения сняты из
/// прототипа; единицы CSS `px` соответствуют `pt` один к одному.
public enum Metrics {

  /// Толщина волосяной линии: разделители и рамки.
  public static let hairline: CGFloat = 1

  // MARK: - Радиусы

  /// Радиусы скруглений.
  public enum Radius {

    /// Кнопки и поля.
    public static let small: CGFloat = 6

    /// Карточки и строки списков.
    public static let medium: CGFloat = 8

    /// Панели переводчика, обложка.
    public static let large: CGFloat = 12

    /// Превью скриншота и чип шортката.
    public static let chip: CGFloat = 5

    /// Нижний радиус свёрнутой пилюли.
    public static let notchPill: CGFloat = 20

    /// Нижний радиус развёрнутой панели.
    public static let panel: CGFloat = 22
  }

  // MARK: - Корпус

  /// Размеры окна и его частей.
  public enum Shell {

    /// Минимальная ширина свёрнутой пилюли, если вырез уже неё или его нет.
    public static let collapsedMinimumWidth: CGFloat = 218

    /// Высота пилюли.
    public static let barHeight: CGFloat = 38

    /// Ширина развёрнутой панели.
    public static let expandedWidth: CGFloat = 760

    /// Высота развёрнутой панели без пилюли.
    public static let expandedHeight: CGFloat = 380

    /// Полная высота развёрнутого блока: пилюля плюс панель.
    public static let expandedTotalHeight = barHeight + expandedHeight

    /// Запас по краям экрана для узких дисплеев.
    public static let horizontalScreenInset: CGFloat = 20

    /// Запас сверху и снизу для низких дисплеев.
    public static let verticalScreenInset: CGFloat = 84

    /// Смещение тени силуэта.
    public static let shadowOffsetY: CGFloat = 20

    /// Радиус размытия тени силуэта, как в макете.
    public static let shadowBlur: CGFloat = 44

    /// Тот же радиус в единицах SwiftUI.
    ///
    /// `drop-shadow` в CSS и `.shadow` в SwiftUI считают размытие по-разному: первый берёт
    /// диаметр, второй — стандартное отклонение. Пересчёт живёт здесь, а не во вьюхе.
    public static let shadowRadius = shadowBlur / 2

    /// Непрозрачность тени силуэта.
    public static let shadowOpacity: Double = 0.58

    /// Боковой отступ содержимого пилюли.
    public static let barHorizontalPadding: CGFloat = 8

    /// Отступ слева у развёрнутой пилюли — рейл начинается ближе к краю.
    public static let barLeadingPaddingExpanded: CGFloat = 6

    /// Сторона кнопки в пилюле: шеврон сворачивания.
    public static let barButtonSide: CGFloat = 30

    /// Зазор между элементами правой части пилюли.
    public static let barItemSpacing: CGFloat = 8

    /// Зазор между элементами фирменного блока пилюли.
    public static let brandItemSpacing: CGFloat = 9

    /// Сторона глазка камеры.
    public static let lensSide: CGFloat = 7

    /// Сторона индикатора активности.
    public static let liveDotSide: CGFloat = 6
  }

  // MARK: - Рейл

  /// Размеры боковой панели навигации.
  public enum Rail {

    /// Ширина рейла.
    public static let width: CGFloat = 60

    /// Отступ сверху.
    public static let topPadding: CGFloat = 14

    /// Отступ снизу.
    public static let bottomPadding: CGFloat = 12

    /// Сторона квадрата логотипа.
    public static let logoSide: CGFloat = 17

    /// Отступ от логотипа до первой кнопки.
    ///
    /// В 4,5 раза больше шага между кнопками намеренно: разрыв делает логотип отдельным
    /// уровнем, а не шестой кнопкой. Не выравнивать.
    public static let logoBottomPadding: CGFloat = 18

    /// Шаг между кнопками.
    public static let buttonSpacing: CGFloat = 4

    /// Ширина полоски активного пункта.
    public static let indicatorWidth: CGFloat = 2

    /// Высота полоски активного пункта.
    public static let indicatorHeight: CGFloat = 20

    /// Зазор между кнопкой и подсказкой.
    public static let tooltipSpacing: CGFloat = 6

    /// Минимальная высота, ниже которой навигацию придётся перекомпоновывать.
    public static let minimumHeight: CGFloat = 339

    /// Сторона квадратика логотипа.
    public static let logoDot: CGFloat = 7

    /// Зазор между квадратиками логотипа.
    public static let logoGap: CGFloat = 3

    /// Скругление квадратика логотипа.
    public static let logoDotRadius: CGFloat = 2

    /// Непрозрачность приглушённых квадратиков логотипа.
    public static let logoDimmedOpacity: Double = 0.34
  }

  // MARK: - Контролы

  /// Размеры повторяющихся контролов.
  public enum Control {

    /// Сторона иконочной кнопки, кнопки рейла и кнопки плеера.
    public static let button: CGFloat = 44

    /// Сторона кнопки воспроизведения.
    public static let playButton: CGFloat = 48

    /// Сторона иконки типа в строке списка.
    public static let typeBadge: CGFloat = 34

    /// Сторона крестика удаления карточки.
    public static let deleteButton: CGFloat = 26

    /// Отступ крестика от края карточки.
    public static let deleteButtonInset: CGFloat = 13

    /// Высота контролов строки добавления вставки.
    public static let compactHeight: CGFloat = 34

    /// Минимальная ширина чипа шортката.
    public static let keyChipMinimumWidth: CGFloat = 58

    /// Высота чипа шортката.
    public static let keyChipHeight: CGFloat = 26

    /// Сторона обложки альбома.
    public static let albumArt: CGFloat = 140
  }

  // MARK: - Списки и карточки

  /// Размеры строк и карточек.
  public enum Row {

    /// Высота строки истории копирований.
    public static let clipHeight: CGFloat = 62

    /// Высота строки быстрой вставки.
    public static let snippetHeight: CGFloat = 60

    /// Зазор между колонками строки.
    public static let columnSpacing: CGFloat = 12

    /// Зазор между строками списка.
    public static let listSpacing: CGFloat = 4

    /// Отступы внутри строки: сверху, справа, снизу, слева.
    public static let insets = EdgeValues(top: 8, leading: 10, bottom: 8, trailing: 8)

    /// Ширина карточки скриншота.
    public static let cardWidth: CGFloat = 238

    /// Высота превью карточки скриншота.
    public static let cardThumbnailHeight: CGFloat = 126

    /// Отступ внутри карточки скриншота.
    public static let cardPadding: CGFloat = 6

    /// Зазор между карточками в ленте.
    public static let cardSpacing: CGFloat = 10
  }

  // MARK: - Контентная область

  /// Отступы области содержимого.
  public enum Content {

    /// Отступ сверху.
    public static let topPadding: CGFloat = 12

    /// Отступ по бокам.
    public static let horizontalPadding: CGFloat = 14

    /// Отступ снизу.
    public static let bottomPadding: CGFloat = 14

    /// Полезная высота при развёрнутой панели.
    public static let usableHeight =
      Shell.expandedHeight - topPadding - bottomPadding
  }

  // MARK: - Фокус

  /// Кольцо фокуса.
  public enum Focus {

    /// Толщина кольца.
    public static let ringWidth: CGFloat = 2

    /// Непрозрачность кольца.
    public static let ringOpacity: Double = 0.30
  }
}

/// Отступы по четырём сторонам.
public struct EdgeValues: Equatable, Sendable {

  /// Отступ сверху.
  public let top: CGFloat

  /// Отступ от ведущего края.
  public let leading: CGFloat

  /// Отступ снизу.
  public let bottom: CGFloat

  /// Отступ от завершающего края.
  public let trailing: CGFloat

  /// Создаёт набор отступов.
  /// - Parameters:
  ///   - top: отступ сверху.
  ///   - leading: отступ от ведущего края.
  ///   - bottom: отступ снизу.
  ///   - trailing: отступ от завершающего края.
  public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
    self.top = top
    self.leading = leading
    self.bottom = bottom
    self.trailing = trailing
  }
}
