import SwiftUI

/// Иконочная кнопка 44 × 44.
///
/// Встречается в трёх модулях, поэтому живёт здесь, а не копируется по вьюхам.
/// При наведении меняется только фон: иконка светлеет с `muted` до `fg` и никогда
/// не темнеет.
public struct IconButton: View {

  private let systemImage: String
  private let label: String
  private let role: Role
  private let isConfirming: Bool
  private let action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isFocused: Bool
  @State private var isHovering = false

  /// Назначение кнопки.
  public enum Role: Sendable {

    /// Обычное действие.
    case regular

    /// Удаление: при наведении заливка становится красной.
    case destructive
  }

  /// Создаёт кнопку.
  /// - Parameters:
  ///   - systemImage: имя символа SF Symbols.
  ///   - label: метка для VoiceOver — что именно делает кнопка, а не «Кнопка».
  ///   - role: назначение кнопки.
  ///   - isConfirming: показывать ли галочку вместо иконки.
  ///   - action: действие по нажатию.
  public init(
    systemImage: String,
    label: String,
    role: Role = .regular,
    isConfirming: Bool = false,
    action: @escaping () -> Void
  ) {
    self.systemImage = systemImage
    self.label = label
    self.role = role
    self.isConfirming = isConfirming
    self.action = action
  }

  /// Содержимое вью.
  public var body: some View {
    Button(action: action) {
      Image(systemName: isConfirming ? "checkmark" : systemImage)
        .foregroundStyle(foreground)
        .frame(width: Metrics.Control.button, height: Metrics.Control.button)
        .background(background, in: .rect(cornerRadius: Metrics.Radius.small))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .focusRing(isFocused, cornerRadius: Metrics.Radius.small)
    .onHover { isHovering = $0 }
    .animation(Motion.fast(reduceMotion: reduceMotion), value: isHovering)
    .animation(Motion.fast(reduceMotion: reduceMotion), value: isConfirming)
    .accessibilityLabel(label)
  }

  private var foreground: Color {
    if isConfirming { return Palette.success }
    return isHovering ? Palette.fg : Palette.muted
  }

  private var background: Color {
    guard isHovering else { return Fill.rest }
    return role == .destructive ? Palette.danger.opacity(0.32) : Fill.iconButtonHover
  }
}
