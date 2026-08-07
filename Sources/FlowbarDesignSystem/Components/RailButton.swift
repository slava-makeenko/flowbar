import SwiftUI

/// Кнопка бокового рейла с подсказкой и полоской активного пункта.
public struct RailButton: View {

  private let systemImage: String
  private let title: String
  private let shortcut: String?
  private let isSelected: Bool
  private let action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isFocused: Bool
  @State private var isHovering = false

  /// Смещение полоски: она прижата к левому краю рейла, а не к краю кнопки.
  private static let indicatorOffset = -(Metrics.Rail.width - Metrics.Control.button) / 2

  /// Создаёт кнопку рейла.
  /// - Parameters:
  ///   - systemImage: имя символа SF Symbols.
  ///   - title: название модуля; оно же метка для VoiceOver.
  ///   - shortcut: шорткат в подсказке, если он есть.
  ///   - isSelected: активен ли пункт.
  ///   - action: действие по нажатию.
  public init(
    systemImage: String,
    title: String,
    shortcut: String? = nil,
    isSelected: Bool,
    action: @escaping () -> Void
  ) {
    self.systemImage = systemImage
    self.title = title
    self.shortcut = shortcut
    self.isSelected = isSelected
    self.action = action
  }

  /// Содержимое вью.
  public var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .foregroundStyle(foreground)
        .frame(width: Metrics.Control.button, height: Metrics.Control.button)
        .background(background, in: .rect(cornerRadius: Metrics.Radius.medium))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .focusRing(isFocused, cornerRadius: Metrics.Radius.medium)
    .overlay(alignment: .leading) { indicator }
    .overlay(alignment: .trailing) { tooltip }
    .onHover { isHovering = $0 }
    .animation(Motion.fast(reduceMotion: reduceMotion), value: isHovering)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  @ViewBuilder private var indicator: some View {
    if isSelected {
      UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: Metrics.Radius.small / 3,
        topTrailingRadius: Metrics.Radius.small / 3
      )
      .fill(Palette.accentHover)
      .frame(width: Metrics.Rail.indicatorWidth, height: Metrics.Rail.indicatorHeight)
      .offset(x: Self.indicatorOffset)
    }
  }

  @ViewBuilder private var tooltip: some View {
    if isHovering || isFocused {
      RailTooltip(title: title, shortcut: shortcut)
        .fixedSize()
        .offset(x: Metrics.Control.button + Metrics.Rail.tooltipSpacing)
        .allowsHitTesting(false)
    }
  }

  private var foreground: Color {
    if isSelected { return Palette.accentHover }
    return isHovering ? Palette.fg : Palette.muted
  }

  private var background: Color {
    if isSelected { return Fill.railButtonSelected }
    return isHovering ? Fill.railButtonHover : Fill.rest
  }
}

/// Подсказка справа от кнопки рейла.
struct RailTooltip: View {

  let title: String
  let shortcut: String?

  var body: some View {
    HStack(spacing: 7) {
      Text(title)
        .typeStyle(.caption)
        .foregroundStyle(Palette.fg)
      if let shortcut {
        Text(shortcut)
          .typeStyle(.monoCaption)
          .foregroundStyle(Palette.muted)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(Palette.surface, in: .rect(cornerRadius: Metrics.Radius.small))
    .overlay {
      RoundedRectangle(cornerRadius: Metrics.Radius.small)
        .stroke(Palette.border, lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
  }
}
