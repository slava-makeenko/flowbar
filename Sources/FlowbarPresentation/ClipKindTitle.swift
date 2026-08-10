import FlowbarDomain

extension ClipKind {

  /// Название вида для интерфейса.
  public var title: String {
    switch self {
    case .text: "Текст"
    case .link: "Ссылка"
    case .code: "Код"
    case .image: "Изображение"
    case .color: "Цвет"
    case .address: "Адрес"
    case .path: "Путь"
    case .value: "Значение"
    case .email: "Почта"
    }
  }

  /// Набирать ли превью моноширинным.
  public var prefersMonospacedPreview: Bool {
    switch self {
    case .path, .color, .value, .code: true
    case .text, .link, .image, .address, .email: false
    }
  }
}
