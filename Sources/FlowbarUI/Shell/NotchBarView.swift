import FlowbarDesignSystem
import FlowbarPresentation
import SwiftUI

/// Пилюля под вырезом.
struct NotchBarView: View {

  let geometry: NotchGeometry
  let state: ShellState
  let activity: AgentActivityModel

  var body: some View {
    HStack(spacing: 0) {
      brandKey
      if state.isExpanded {
        Spacer(minLength: 0)
        collapseButton
      }
    }
    .padding(.leading, leadingPadding)
    .padding(.trailing, Metrics.Shell.barHorizontalPadding)
    .frame(
      width: state.isExpanded ? geometry.expandedWidth : geometry.collapsedWidth,
      height: Metrics.Shell.barHeight
    )
    .overlay(alignment: .leading) { agentIndicator }
    .background(geometry.bodyColor)
    .clipShape(
      .rect(
        bottomLeadingRadius: bottomRadius,
        bottomTrailingRadius: bottomRadius
      )
    )
  }

  private var brandKey: some View {
    Button {
      state.togglePin()
    } label: {
      HStack(spacing: Metrics.Shell.brandItemSpacing) {
        Circle()
          .fill(Palette.lens)
          .frame(width: Metrics.Shell.lensSide, height: Metrics.Shell.lensSide)
        Text("Flowbar")
          .typeStyle(.button)
          .foregroundStyle(Palette.fg)
        Circle()
          .fill(Palette.success)
          .frame(width: Metrics.Shell.liveDotSide, height: Metrics.Shell.liveDotSide)
      }
      .padding(.horizontal, Metrics.Shell.barHorizontalPadding)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(state.isPinned ? "Открепить панель" : "Закрепить панель")
  }

  /// Только в свёрнутом виде: в развёрнутой панели точки стали бы вторым акцентным пятном
  /// рядом с активным пунктом рейла. Спека §14, ADR-0013.
  @ViewBuilder private var agentIndicator: some View {
    if !state.isExpanded && !activity.working.isEmpty {
      AgentActivityIndicator(
        agents: activity.working,
        accessibilityLabel: activity.accessibilityLabel
      )
      .frame(width: geometry.leftWingWidth)
      .allowsHitTesting(false)
      .transition(.opacity)
    }
  }

  private var collapseButton: some View {
    Button {
      state.dismiss()
    } label: {
      Image(systemName: "chevron.up")
        .foregroundStyle(Palette.muted)
        .frame(width: Metrics.Shell.barButtonSide, height: Metrics.Shell.barButtonSide)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Свернуть панель")
  }

  private var leadingPadding: CGFloat {
    state.isExpanded
      ? Metrics.Shell.barLeadingPaddingExpanded : Metrics.Shell.barHorizontalPadding
  }

  private var bottomRadius: CGFloat {
    state.isExpanded ? 0 : Metrics.Radius.notchPill
  }
}
