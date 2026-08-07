import FlowbarDesignSystem
import FlowbarPresentation
import SwiftUI

/// Силуэт панели: пилюля и растущая под ней панель.
///
/// Панель растёт высотой от нуля, а не проявляется прозрачностью — это то, что делает
/// жест похожим на разворачивание физического выреза.
public struct NotchShellView: View {

  private let geometry: NotchGeometry
  private let state: ShellState

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Создаёт оболочку.
  /// - Parameters:
  ///   - geometry: геометрия окна на текущем экране.
  ///   - state: состояние раскрытия и навигации.
  public init(geometry: NotchGeometry, state: ShellState) {
    self.geometry = geometry
    self.state = state
  }

  /// Содержимое вью.
  public var body: some View {
    VStack(spacing: 0) {
      NotchBarView(geometry: geometry, state: state)
      panel
    }
    .compositingGroup()
    .shadow(
      color: .black.opacity(Metrics.Shell.shadowOpacity),
      radius: Metrics.Shell.shadowRadius,
      y: Metrics.Shell.shadowOffsetY
    )
    .frame(
      width: geometry.contentSize.width,
      height: geometry.contentSize.height,
      alignment: .top
    )
    .animation(Motion.unfold(reduceMotion: reduceMotion), value: state.isExpanded)
  }

  private var panel: some View {
    HStack(spacing: 0) {
      RailView(state: state)
      ModulePlaceholderView(module: state.activeModule)
    }
    .frame(width: geometry.expandedWidth, height: geometry.panelHeight, alignment: .top)
    .opacity(state.isExpanded ? 1 : 0)
    .offset(y: state.isExpanded ? 0 : Motion.contentOffsetY)
    .animation(contentAnimation, value: state.isExpanded)
    .background(geometry.bodyColor)
    .frame(height: state.isExpanded ? geometry.panelHeight : 0, alignment: .top)
    .clipShape(
      .rect(
        bottomLeadingRadius: Metrics.Radius.panel,
        bottomTrailingRadius: Metrics.Radius.panel
      )
    )
  }

  /// Содержимое появляется с задержкой после начала разворота и уходит сразу.
  private var contentAnimation: Animation? {
    guard let unfold = Motion.unfold(reduceMotion: reduceMotion) else { return nil }
    return state.isExpanded ? unfold.delay(Motion.contentDelay) : unfold
  }
}

extension NotchGeometry {

  /// Цвет корпуса.
  ///
  /// На экране с вырезом — чистый чёрный: любое отклонение даёт видимый шов по краю
  /// физического выреза. ADR-0004.
  var bodyColor: Color {
    hasNotch ? Palette.bgNotched : Palette.bg
  }
}
