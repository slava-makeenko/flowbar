import FlowbarPresentation

extension ShellModule {

  /// Символ SF Symbols для кнопки рейла.
  ///
  /// Названия модулей — забота слоя представления, рисунок иконки — забота UI.
  var systemImage: String {
    switch self {
    case .clipboard: "list.clipboard"
    case .screenshots: "camera.viewfinder"
    case .translate: "character.bubble"
    case .snippets: "bolt"
    case .limits: "gauge.with.dots.needle.33percent"
    case .settings: "gearshape"
    }
  }
}
