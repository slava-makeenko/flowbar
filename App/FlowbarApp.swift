import AppKit

/// Точка входа.
///
/// Приложение резидентное: политика `.accessory` убирает иконку из Dock и главное меню.
/// `LSUIElement` в `Info.plist` делает то же самое до запуска — оба нужны, иначе в момент
/// старта успевает мигнуть иконка.
@main
@MainActor
enum FlowbarApp {

  /// Делегат хранится статически: `NSApplication.delegate` — слабая ссылка.
  private static let delegate = AppDelegate()

  static func main() {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    application.delegate = delegate
    application.run()
  }
}

/// Делегат приложения. Держит композиционный корень, пока приложение живо.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

  private let root = CompositionRoot()

  func applicationDidFinishLaunching(_ notification: Notification) {
    root.start()
  }
}
