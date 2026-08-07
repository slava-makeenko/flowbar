import FlowbarDesignSystem
import FlowbarPresentation
import SwiftUI

/// Заглушка содержимого модуля.
///
/// Живёт до фаз 5–9 пайплайна: рейл и переключение экранов нужны шеллу уже сейчас,
/// а сами модули приходят позже. Удаляется вместе с последним из них.
struct ModulePlaceholderView: View {

  let module: ShellModule

  var body: some View {
    VStack(spacing: Metrics.Row.listSpacing) {
      Text(module.title)
        .typeStyle(.listRow)
        .foregroundStyle(Palette.fg2)
      Text("Модуль появится в своей фазе")
        .typeStyle(.metadata)
        .foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, Metrics.Content.topPadding)
    .padding(.horizontal, Metrics.Content.horizontalPadding)
    .padding(.bottom, Metrics.Content.bottomPadding)
  }
}
