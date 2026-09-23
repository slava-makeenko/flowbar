import AppKit
import FlowbarDesignSystem
import FlowbarDomain
import SwiftUI

/// Точки работающих агентов в левом крыле свёрнутой пилюли. ADR-0013.
///
/// Никто не работает — в крыле ничего нет, и пилюля неотличима от выреза.
struct AgentActivityIndicator: View {

  let agents: [Agent]
  let accessibilityLabel: String?

  var body: some View {
    VStack(spacing: Metrics.Shell.agentDotSpacing) {
      ForEach(agents, id: \.self) { agent in
        AgentDot(color: agent.color)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel ?? "")
    .accessibilityHidden(accessibilityLabel == nil)
  }
}

/// Пульсирующая точка агента.
///
/// Пульсация — `CABasicAnimation` слоя, а не SwiftUI `repeatForever`: ту крутит процесс,
/// перерисовывая хост окна на каждом кадре, и замер дал ~11 % CPU на всё время работы
/// агента. Анимацию слоя ведёт render server, процесс в ней не участвует. ADR-0013, R10.
private struct AgentDot: NSViewRepresentable {

  let color: Color

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeNSView(context: Context) -> PulsingDotView {
    PulsingDotView()
  }

  func updateNSView(_ view: PulsingDotView, context: Context) {
    view.update(
      color: color.resolve(in: context.environment).cgColor,
      pulses: !reduceMotion
    )
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: PulsingDotView, context: Context)
    -> CGSize?
  {
    CGSize(width: Metrics.Shell.agentDotSide, height: Metrics.Shell.agentDotSide)
  }
}

/// Круглый слой с бесконечной анимацией прозрачности.
final class PulsingDotView: NSView {

  private static let animationKey = "pulse"

  override init(frame: CGRect) {
    super.init(frame: frame)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) не поддерживается")
  }

  override func layout() {
    super.layout()
    layer?.cornerRadius = bounds.width / 2
  }

  /// Задаёт цвет и включает или выключает пульсацию.
  /// - Parameters:
  ///   - color: цвет точки.
  ///   - pulses: пульсировать ли; при Reduce Motion точка горит ровно.
  func update(color: CGColor, pulses: Bool) {
    guard let layer else { return }
    layer.backgroundColor = color

    let isPulsing = layer.animation(forKey: Self.animationKey) != nil
    guard pulses != isPulsing else { return }
    guard pulses else {
      layer.removeAnimation(forKey: Self.animationKey)
      return
    }

    let pulse = CABasicAnimation(keyPath: "opacity")
    pulse.fromValue = 1
    pulse.toValue = Motion.agentPulseDimmedOpacity
    pulse.duration = Motion.agentPulseHalfPeriod
    pulse.autoreverses = true
    pulse.repeatCount = .infinity
    pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    // Панель резидентная и живёт весь день: анимация не должна слететь при уходе
    // окна с экрана и возвращении.
    pulse.isRemovedOnCompletion = false
    layer.add(pulse, forKey: Self.animationKey)
  }
}
