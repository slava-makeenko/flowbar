import AppKit
import FlowbarDesignSystem

extension NSScreen {

  /// Ширина физического выреза, если он есть.
  ///
  /// Считается как остаток экрана между областями строки меню слева и справа от выреза.
  public var notchWidth: CGFloat? {
    guard safeAreaInsets.top > 0,
      let left = auxiliaryTopLeftArea,
      let right = auxiliaryTopRightArea
    else { return nil }
    return frame.width - left.width - right.width
  }
}

/// Геометрия окна на конкретном экране.
///
/// Окно одно и постоянного размера — развёрнутое состояние плюс поле под тень. Менять
/// размер окна на наведение нельзя: `NSWindow` не анимирует `setFrame` синхронно
/// с содержимым, будет рассинхрон и мерцание.
public struct NotchGeometry: Equatable, Sendable {

  /// У экрана есть физический вырез.
  public let hasNotch: Bool

  /// Ширина свёрнутой пилюли.
  public let collapsedWidth: CGFloat

  /// Видимая ширина пилюли слева от выреза — место для индикатора агентов.
  ///
  /// На экране без выреза видна вся пилюля, и крыло — это свободное поле перед глазком.
  public let leftWingWidth: CGFloat

  /// Ширина развёрнутой панели.
  public let expandedWidth: CGFloat

  /// Высота развёрнутой панели без пилюли.
  public let panelHeight: CGFloat

  /// Кадр окна в глобальных координатах экрана.
  public let windowFrame: CGRect

  /// Размер содержимого окна.
  public var contentSize: CGSize { windowFrame.size }

  /// Силуэт свёрнутого состояния в координатах содержимого окна.
  public var collapsedShape: CGRect {
    CGRect(
      x: (contentSize.width - collapsedWidth) / 2,
      y: contentSize.height - Metrics.Shell.barHeight,
      width: collapsedWidth,
      height: Metrics.Shell.barHeight
    )
  }

  /// Силуэт развёрнутого состояния в координатах содержимого окна.
  ///
  /// Пилюля и панель одной ширины, поэтому объединение — один прямоугольник.
  public var expandedShape: CGRect {
    CGRect(
      x: (contentSize.width - expandedWidth) / 2,
      y: contentSize.height - Metrics.Shell.barHeight - panelHeight,
      width: expandedWidth,
      height: Metrics.Shell.barHeight + panelHeight
    )
  }

  /// Экран, на котором должна жить панель.
  ///
  /// Первый экран с вырезом, иначе главный. За активным экраном панель не следует —
  /// ADR-0005.
  public static func preferredScreen() -> NSScreen? {
    NSScreen.screens.first { $0.notchWidth != nil } ?? NSScreen.main
  }

  /// Считает геометрию для экрана.
  /// - Parameter screen: экран, на котором живёт панель.
  /// - Returns: геометрия окна.
  public static func make(for screen: NSScreen) -> NotchGeometry {
    let notchWidth = screen.notchWidth
    // Крылья по бокам выреза не должны стать уже точки индикатора агентов. ADR-0013.
    let collapsed = max(
      (notchWidth ?? 0) + Metrics.Shell.agentWingMinimum * 2,
      Metrics.Shell.collapsedMinimumWidth
    )
    let leftWing = notchWidth.map { (collapsed - $0) / 2 } ?? Metrics.Shell.agentWingMinimum
    let expanded = min(
      Metrics.Shell.expandedWidth,
      screen.frame.width - Metrics.Shell.horizontalScreenInset
    )
    let panelHeight = min(
      Metrics.Shell.expandedHeight,
      screen.frame.height - Metrics.Shell.verticalScreenInset
    )

    // Поле под тень: она уходит вниз, поэтому снизу нужно и размытие, и смещение.
    let windowWidth = expanded + Metrics.Shell.shadowBlur * 2
    let windowHeight =
      Metrics.Shell.barHeight + panelHeight + Metrics.Shell.shadowBlur
      + Metrics.Shell.shadowOffsetY

    return NotchGeometry(
      hasNotch: notchWidth != nil,
      collapsedWidth: collapsed,
      leftWingWidth: leftWing,
      expandedWidth: expanded,
      panelHeight: panelHeight,
      windowFrame: CGRect(
        x: screen.frame.midX - windowWidth / 2,
        y: screen.frame.maxY - windowHeight,
        width: windowWidth,
        height: windowHeight
      )
    )
  }
}
