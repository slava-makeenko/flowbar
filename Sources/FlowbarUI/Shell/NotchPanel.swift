import AppKit

/// Окно панели.
///
/// `.nonactivatingPanel` обязателен: без него клик по панели заберёт фокус у активного
/// приложения, и «скопировать → вставить в редактор» перестанет работать как единый жест.
public final class NotchPanel: NSPanel {

  /// Создаёт окно.
  /// - Parameter contentRect: кадр окна в глобальных координатах.
  public init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    // Тень рисуется в SwiftUI по силуэту: системная тень обвела бы прямоугольник окна,
    // включая прозрачное поле вокруг панели.
    hasShadow = false
    // Порядок важен: `isFloatingPanel` сам выставляет уровень `.floating`, поэтому
    // уровень назначается после него, иначе панель окажется под строкой меню.
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isMovable = false
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
  }

  /// Отключает подгонку кадра под видимую область экрана.
  ///
  /// По умолчанию AppKit не пускает окно под строку меню и сдвигает его вниз на её высоту.
  /// Панель обязана начинаться от самого верха экрана, иначе между ней и физическим
  /// вырезом остаётся полоса в 33 pt.
  /// - Parameters:
  ///   - frameRect: предложенный кадр.
  ///   - screen: экран, к которому подгоняется кадр.
  /// - Returns: тот же кадр без изменений.
  public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  /// Окно может стать ключевым: без этого `TextField` в переводчике не примет ввод.
  ///
  /// Ключевым оно станет только по явному клику в поле — `.nonactivatingPanel`
  /// не активирует само приложение.
  public override var canBecomeKey: Bool { true }

  /// Окно не становится главным: главное окно у приложения без интерфейса лишнее.
  public override var canBecomeMain: Bool { false }
}
