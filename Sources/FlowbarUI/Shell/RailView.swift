import FlowbarDesignSystem
import FlowbarPresentation
import SwiftUI

/// Боковой рейл навигации.
struct RailView: View {

  let state: ShellState

  var body: some View {
    VStack(spacing: 0) {
      RailLogo()
        .padding(.bottom, Metrics.Rail.logoBottomPadding)

      VStack(spacing: Metrics.Rail.buttonSpacing) {
        ForEach(ShellModule.allCases) { module in
          RailButton(
            systemImage: module.systemImage,
            title: module.title,
            shortcut: module.shortcut,
            isSelected: state.activeModule == module
          ) {
            state.activeModule = module
            state.pin()
          }
        }
      }

      Spacer(minLength: 0)

      // Настройки в объём v1 не входят: кнопка нарисована, но ничего не делает — спека §1.
      RailButton(systemImage: "gearshape", title: "Настройки", isSelected: false, action: {})
        .disabled(true)
    }
    .padding(.top, Metrics.Rail.topPadding)
    .padding(.bottom, Metrics.Rail.bottomPadding)
    .frame(width: Metrics.Rail.width)
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(Palette.borderSoft)
        .frame(width: Metrics.hairline)
    }
  }
}

/// Логотип: квадрат 2 × 2 из точек, диагональ приглушена.
private struct RailLogo: View {

  private static let columns = Array(
    repeating: GridItem(.fixed(Metrics.Rail.logoDot), spacing: Metrics.Rail.logoGap),
    count: 2
  )

  var body: some View {
    LazyVGrid(columns: Self.columns, spacing: Metrics.Rail.logoGap) {
      ForEach(0..<4, id: \.self) { index in
        RoundedRectangle(cornerRadius: Metrics.Rail.logoDotRadius)
          .fill(Palette.fg)
          .frame(width: Metrics.Rail.logoDot, height: Metrics.Rail.logoDot)
          .opacity(isDimmed(index) ? Metrics.Rail.logoDimmedOpacity : 1)
      }
    }
    .frame(width: Metrics.Rail.logoSide)
    .accessibilityHidden(true)
  }

  private func isDimmed(_ index: Int) -> Bool {
    index == 1 || index == 2
  }
}
