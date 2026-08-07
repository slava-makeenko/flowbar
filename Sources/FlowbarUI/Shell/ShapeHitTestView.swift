import AppKit

/// Корневая вью окна: пропускает клики мимо силуэта и следит за наведением.
///
/// Окно всегда большого размера, но кликабельно только там, где нарисован чёрный силуэт.
/// Иначе прозрачная область перехватила бы клики по приложению под ней.
public final class ShapeHitTestView: NSView {

  /// Текущий силуэт в координатах этой вью.
  public var visibleShape: @MainActor () -> CGRect = { .zero }

  /// Курсор вошёл в силуэт.
  public var onMouseEntered: @MainActor () -> Void = {}

  /// Курсор покинул силуэт.
  public var onMouseExited: @MainActor () -> Void = {}

  private var shapeTrackingArea: NSTrackingArea?

  public override func hitTest(_ point: NSPoint) -> NSView? {
    let local = superview.map { convert(point, from: $0) } ?? point
    return visibleShape().contains(local) ? super.hitTest(point) : nil
  }

  /// Пересобирает область отслеживания под текущий силуэт.
  ///
  /// Область задаётся прямоугольником силуэта, а не `.inVisibleRect`: с флагом
  /// отслеживался бы весь кадр окна вместе с прозрачным полем, и панель разворачивалась
  /// бы от наведения на пустое место в стороне от выреза.
  public func refreshTrackingArea() {
    if let existing = shapeTrackingArea { removeTrackingArea(existing) }
    let area = NSTrackingArea(
      rect: visibleShape(),
      options: [.mouseEnteredAndExited, .activeAlways],
      owner: self
    )
    addTrackingArea(area)
    shapeTrackingArea = area
  }

  public override func updateTrackingAreas() {
    super.updateTrackingAreas()
    refreshTrackingArea()
  }

  public override func mouseEntered(with event: NSEvent) {
    guard isOurs(event) else { return super.mouseEntered(with: event) }
    onMouseEntered()
  }

  public override func mouseExited(with event: NSEvent) {
    guard isOurs(event) else { return super.mouseExited(with: event) }
    onMouseExited()
  }

  /// Событие пришло от нашей области отслеживания, а не всплыло снизу.
  ///
  /// `NSHostingView` ставит собственную область на весь свой кадр — ей нужен hover
  /// для кнопок SwiftUI. Своё событие она не потребляет, а реализация `NSResponder`
  /// по умолчанию передаёт его выше по цепочке, то есть нам. Без этой проверки панель
  /// разворачивалась от наведения на любую точку окна, включая прозрачное поле под тень:
  /// граница срабатывания приходилась на край окна, а не на край силуэта.
  private func isOurs(_ event: NSEvent) -> Bool {
    event.trackingArea === shapeTrackingArea
  }
}
