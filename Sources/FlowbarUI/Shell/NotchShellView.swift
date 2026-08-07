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
  private let clipboard: ClipboardViewModel
  private let translate: TranslateViewModel
  private let snippets: SnippetsViewModel
  private let feedback: CopyFeedback
  private let backgroundHosts: AnyView

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Создаёт оболочку.
  /// - Parameters:
  ///   - geometry: геометрия окна на текущем экране.
  ///   - state: состояние раскрытия и навигации.
  ///   - clipboard: вью-модель истории копирований.
  ///   - translate: вью-модель перевода.
  ///   - snippets: вью-модель быстрых вставок.
  ///   - feedback: подтверждение копирования.
  ///   - backgroundHosts: невидимые вью, которым нужен доступ к системным сессиям.
  public init(
    geometry: NotchGeometry,
    state: ShellState,
    clipboard: ClipboardViewModel,
    translate: TranslateViewModel,
    snippets: SnippetsViewModel,
    feedback: CopyFeedback,
    backgroundHosts: AnyView
  ) {
    self.geometry = geometry
    self.state = state
    self.clipboard = clipboard
    self.translate = translate
    self.snippets = snippets
    self.feedback = feedback
    self.backgroundHosts = backgroundHosts
  }

  /// Содержимое вью.
  public var body: some View {
    VStack(spacing: 0) {
      NotchBarView(geometry: geometry, state: state)
      panel
    }
    .overlay(alignment: .top) { backgroundHosts }
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
      moduleContent
        .padding(.top, Metrics.Content.topPadding)
        .padding(.horizontal, Metrics.Content.horizontalPadding)
        .padding(.bottom, Metrics.Content.bottomPadding)
    }
    .frame(width: geometry.expandedWidth, height: geometry.panelHeight, alignment: .top)
    .overlay(alignment: .bottom) { toast }
    // Любой клик внутри панели закрепляет её: иначе панель схлопнется, пока пользователь
    // печатает. Жест одновременный, чтобы не перехватывать нажатия у кнопок.
    .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in state.pin() })
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

  @ViewBuilder private var moduleContent: some View {
    switch state.activeModule {
    case .clipboard:
      ClipboardView(model: clipboard)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    case .translate:
      TranslateView(model: translate)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .snippets:
      SnippetsView(model: snippets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    case .screenshots, .music:
      ModulePlaceholderView(module: state.activeModule)
    }
  }

  @ViewBuilder private var toast: some View {
    if let message = feedback.message {
      Toast(message: message)
        .padding(.bottom, Metrics.Content.bottomPadding)
        .transition(.opacity)
    }
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
