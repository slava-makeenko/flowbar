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

    /// Сегмент переключателя видов.
    public static let segment: CGFloat = 4

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

    /// Зазор между контролами компактной строки.
    public static let compactSpacing: CGFloat = 6

    /// Внутренний отступ переключателя видов.
    public static let segmentedPadding: CGFloat = 2

    /// Высота сегмента переключателя.
    public static let segmentHeight: CGFloat = 28

    /// Боковой отступ внутри сегмента.
    public static let segmentHorizontalPadding: CGFloat = 10

    /// Боковой отступ внутри поля ввода.
    public static let fieldHorizontalPadding: CGFloat = 11

    /// Боковой отступ внутри основной кнопки.
    public static let primaryHorizontalPadding: CGFloat = 13
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

    /// Зазор между кнопками действий в строке.
    public static let actionSpacing: CGFloat = 2

    /// Отступ под строкой добавления.
    public static let formBottomSpacing: CGFloat = 8

    /// Отступ под строкой подсказки.
    public static let hintBottomSpacing: CGFloat = 10

    /// Вертикальный отступ пустого состояния.
    public static let emptyStateVerticalPadding: CGFloat = 34
  }

  // MARK: - Плеер

  /// Размеры экрана музыки.
  public enum Player {

    /// Зазор между обложкой и сведениями о треке.
    public static let topSpacing: CGFloat = 20

    /// Отступ под подписью источника.
    public static let sourceBottomSpacing: CGFloat = 12

    /// Отступ под названием трека.
    public static let titleBottomSpacing: CGFloat = 5

    /// Отступ над блоком прогресса.
    public static let progressTopPadding: CGFloat = 18

    /// Отступ над строкой времени.
    public static let timeTopPadding: CGFloat = 8

    /// Отступ над кнопками транспорта.
    public static let controlsTopPadding: CGFloat = 16

    /// Зазор между кнопками транспорта.
    public static let controlsSpacing: CGFloat = 14

    /// Зазор в строке громкости.
    public static let volumeSpacing: CGFloat = 12

    /// Сторона иконки громкости.
    public static let volumeIcon: CGFloat = 18

    /// Толщина дорожки ползунка.
    public static let sliderHeight: CGFloat = 4

    /// Сторона бегунка.
    public static let sliderThumb: CGFloat = 13

    /// Половина бегунка: на неё он сдвигается, чтобы центр совпал с позицией.
    public static let sliderThumbRadius = sliderThumb / 2

    /// Предельная ширина плеера.
    public static let maximumWidth: CGFloat = 560
  }

  // MARK: - Снимки

  /// Размеры ленты снимков.
  public enum Screenshots {

    /// Отступ над блоком шорткатов захвата.
    public static let hintsTopPadding: CGFloat = 13

    /// Отступ под надзаголовком блока шорткатов.
    public static let hintsLabelBottomPadding: CGFloat = 9

    /// Высота строки шортката.
    public static let hintRowHeight: CGFloat = 30

    /// Зазор между чипом и подписью шортката.
    public static let hintSpacing: CGFloat = 12

    /// Отступ над именем файла на карточке.
    public static let metaTopPadding: CGFloat = 9

    /// Отступ над подписью с размерами.
    public static let captionTopPadding: CGFloat = 4

    /// Высота пустого состояния ленты.
    public static let emptyHeight: CGFloat = 181
  }

  // MARK: - Переводчик

  /// Размеры экрана перевода.
  public enum Translate {

    /// Ширина колонки с кнопкой обмена языками.
    public static let swapColumnWidth: CGFloat = 46

    /// Зазор между панелями.
    public static let paneSpacing: CGFloat = 12

    /// Вертикальный отступ внутри панели.
    public static let panePaddingVertical: CGFloat = 13

    /// Боковой отступ внутри панели.
    public static let panePaddingHorizontal: CGFloat = 14

    /// Отступ под шапкой панели.
    public static let headBottomPadding: CGFloat = 10

    /// Отступ над подвалом панели.
    public static let footTopPadding: CGFloat = 6

    /// Вертикальный отступ поля ввода.
    public static let editorVerticalPadding: CGFloat = 14

    /// Высота селектора языка.
    public static let languagePickerHeight: CGFloat = 30

    /// Боковой отступ внутри селектора языка.
    public static let languagePickerPadding: CGFloat = 7
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
