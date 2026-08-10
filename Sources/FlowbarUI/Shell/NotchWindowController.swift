import AppKit
import FlowbarDesignSystem
import FlowbarPresentation
import Observation
import SwiftUI

/// Владелец окна панели.
///
/// Держит окно, силуэт для hit-тестинга, область отслеживания наведения и мониторы
/// событий. Всё, что связывает AppKit с состоянием оболочки, собрано здесь.
@MainActor
public final class NotchWindowController {

  private let state: ShellState
  private let clipboard: ClipboardViewModel
  private let settings: SettingsViewModel
  private let music: MusicViewModel
  private let screenshots: ScreenshotsViewModel
  private let translate: TranslateViewModel
  private let snippets: SnippetsViewModel
  private let feedback: CopyFeedback
  private let backgroundHosts: AnyView

  private var panel: NotchPanel?
  private var hitTestView: ShapeHitTestView?
  private var hostingView: NSHostingView<NotchShellView>?
  private var geometry: NotchGeometry?

  private var globalClickMonitor: Any?
  private var localKeyMonitor: Any?
  private var screenObserver: NSObjectProtocol?

  /// Силуэт держится развёрнутым до конца анимации сворачивания.
  ///
  /// Если переключить его в начале анимации, курсор провалится сквозь ещё видимую панель
  /// в приложение под ней.
  private var isCollapsing = false
  private var collapseTask: Task<Void, Never>?

  /// Создаёт контроллер.
  /// - Parameters:
  ///   - state: состояние оболочки.
  ///   - clipboard: вью-модель истории копирований.
  ///   - settings: вью-модель настроек.
  ///   - music: вью-модель плеера.
  ///   - screenshots: вью-модель ленты снимков.
  ///   - translate: вью-модель перевода.
  ///   - snippets: вью-модель быстрых вставок.
  ///   - feedback: подтверждение копирования.
  ///   - backgroundHosts: невидимые вью, которым нужен доступ к системным сессиям.
  public init(
    state: ShellState,
    clipboard: ClipboardViewModel,
    settings: SettingsViewModel,
    music: MusicViewModel,
    screenshots: ScreenshotsViewModel,
    translate: TranslateViewModel,
    snippets: SnippetsViewModel,
    feedback: CopyFeedback,
    backgroundHosts: AnyView
  ) {
    self.state = state
    self.clipboard = clipboard
    self.settings = settings
    self.music = music
    self.screenshots = screenshots
    self.translate = translate
    self.snippets = snippets
    self.feedback = feedback
    self.backgroundHosts = backgroundHosts
  }

  /// Поднимает окно и подписки.
  public func start() {
    rebuildWindow()
    observeExpansion()
    installMonitors()
    observeScreenChanges()
  }

  /// Делает окно ключевым, чтобы поля принимали ввод.
  ///
  /// Нужно для сочетаний, открывающих модуль с полем: `.nonactivatingPanel` не забирает
  /// фокус сам, и без этого текст уходил бы в приложение под панелью.
  public func makeKey() {
    // Резидентное приложение неактивно, и `.nonactivatingPanel` само его не поднимает —
    // без явной активации окно ключевым не станет, а ввод уйдёт в приложение под панелью.
    // Для сочетания это верно: пользователь именно просил печатать здесь.
    NSApp.activate()
    panel?.makeKeyAndOrderFront(nil)
  }

  /// Снимает подписки и закрывает окно.
  public func stop() {
    collapseTask?.cancel()
    if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
    if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
    if let observer = screenObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    globalClickMonitor = nil
    localKeyMonitor = nil
    screenObserver = nil
    panel?.orderOut(nil)
  }

  // MARK: - Окно

  private func rebuildWindow() {
    guard let screen = NotchGeometry.preferredScreen() else { return }
    let geometry = NotchGeometry.make(for: screen)
    self.geometry = geometry

    let panel = self.panel ?? NotchPanel(contentRect: geometry.windowFrame)
    panel.setFrame(geometry.windowFrame, display: true)

    let root = NotchShellView(
      geometry: geometry,
      state: state,
      clipboard: clipboard,
      settings: settings,
      music: music,
      screenshots: screenshots,
      translate: translate,
      snippets: snippets,
      feedback: feedback,
      backgroundHosts: backgroundHosts
    )
    if let hostingView {
      hostingView.rootView = root
      hostingView.frame = CGRect(origin: .zero, size: geometry.contentSize)
    } else {
      let hostingView = NSHostingView(rootView: root)
      hostingView.frame = CGRect(origin: .zero, size: geometry.contentSize)
      hostingView.autoresizingMask = [.width, .height]

      let hitTestView = ShapeHitTestView(
        frame: CGRect(origin: .zero, size: geometry.contentSize)
      )
      hitTestView.addSubview(hostingView)
      hitTestView.visibleShape = { [weak self] in self?.currentShape() ?? .zero }
      hitTestView.onMouseEntered = { [weak self] in self?.state.mouseEntered() }
      hitTestView.onMouseExited = { [weak self] in self?.state.mouseExited() }

      panel.contentView = hitTestView
      self.hostingView = hostingView
      self.hitTestView = hitTestView
    }

    self.panel = panel
    panel.orderFrontRegardless()
    hitTestView?.refreshTrackingArea()
  }

  private func currentShape() -> CGRect {
    guard let geometry else { return .zero }
    return state.isExpanded || isCollapsing ? geometry.expandedShape : geometry.collapsedShape
  }

  // MARK: - Жизненный цикл силуэта

  private func observeExpansion() {
    withObservationTracking {
      _ = state.isExpanded
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.expansionChanged()
        self?.observeExpansion()
      }
    }
  }

  private func expansionChanged() {
    collapseTask?.cancel()

    guard !state.isExpanded else {
      isCollapsing = false
      hitTestView?.refreshTrackingArea()
      return
    }

    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    guard !reduceMotion else {
      isCollapsing = false
      hitTestView?.refreshTrackingArea()
      return
    }

    isCollapsing = true
    collapseTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(Motion.unfoldDuration))
      guard !Task.isCancelled, let self else { return }
      isCollapsing = false
      hitTestView?.refreshTrackingArea()
    }
  }

  // MARK: - События вне окна

  private func installMonitors() {
    globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { _ in
      Task { @MainActor [weak self] in self?.state.dismiss() }
    }

    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
      guard event.keyCode == Self.escapeKeyCode else { return event }
      Task { @MainActor [weak self] in self?.state.dismiss() }
      return nil
    }
  }

  private func observeScreenChanges() {
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor [weak self] in self?.rebuildWindow() }
    }
  }

  private static let escapeKeyCode: UInt16 = 53
}
