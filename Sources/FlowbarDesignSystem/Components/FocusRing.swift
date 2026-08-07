import SwiftUI

extension View {

  /// Рисует кольцо фокуса вокруг элемента.
  ///
  /// Видимое кольцо обязательно на всех интерактивных элементах: без него панель
  /// непроходима с клавиатуры, а это отдельный пункт чеклиста приёмки.
  /// - Parameters:
  ///   - isFocused: в фокусе ли элемент.
  ///   - cornerRadius: радиус скругления, совпадающий с формой элемента.
  /// - Returns: вью с кольцом фокуса.
  public func focusRing(_ isFocused: Bool, cornerRadius: CGFloat) -> some View {
    overlay {
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(
          isFocused ? Palette.accent.opacity(Metrics.Focus.ringOpacity) : .clear,
          lineWidth: Metrics.Focus.ringWidth
        )
    }
  }
}
