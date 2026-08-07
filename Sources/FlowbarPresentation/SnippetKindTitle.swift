import FlowbarDomain

extension SnippetKind {

  /// Название вида для интерфейса.
  public var title: String {
    switch self {
    case .email: "Почта"
    case .tag: "Тег"
    case .phone: "Номер"
    }
  }
}
