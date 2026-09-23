import FlowbarDesignSystem
import FlowbarDomain
import SwiftUI

extension Agent {

  /// Цвет агента: точка в пилюле и полосы на экране лимитов.
  ///
  /// Названия — забота представления, цвет — забота UI.
  var color: Color {
    switch self {
    case .claudeCode: Palette.agentClaude
    case .codex: Palette.agentCodex
    }
  }
}
