import FlowbarDesignSystem
import FlowbarDomain
import FlowbarPresentation
import SwiftUI

/// Экран лимитов Claude Code и Codex.
///
/// Полосы окрашены в цвета агентов — те же, что у точек в пилюле: цвет связывает экран
/// с индикатором. Это исключение из правила одного акцентного пятна, спека §14.
struct LimitsView: View {

  @Bindable var model: LimitsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Metrics.Limits.sectionSpacing) {
      ForEach(Agent.allCases, id: \.self) { agent in
        section(for: agent)
      }
      Spacer(minLength: 0)
      footer
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .task { await model.refreshWhileVisible() }
  }

  // MARK: - Агент

  private func section(for agent: Agent) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      heading(for: agent)
        .padding(.bottom, Metrics.Limits.headingBottomPadding)

      if case .usage(let usage) = model.state(of: agent),
        let outdated = model.outdatedText(for: usage)
      {
        Text(outdated)
          .typeStyle(.metadata)
          .foregroundStyle(Palette.fg2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, Metrics.Limits.headingBottomPadding)
      }

      if let advice = model.adviceText(for: agent) {
        Text(advice)
          .typeStyle(.caption)
          .foregroundStyle(Palette.fg)
          .padding(.bottom, Metrics.Limits.headingBottomPadding)
      }

      switch model.state(of: agent) {
      case .needsFolder:
        folderRequest(for: agent)
      case .noData:
        noData(for: agent)
      case .usage(let usage):
        VStack(spacing: Metrics.Limits.windowSpacing) {
          ForEach(usage.windows, id: \.duration) { window in
            windowRow(window, of: usage)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func heading(for agent: Agent) -> some View {
    HStack(spacing: 0) {
      Text(agent.title.uppercased())
        .typeStyle(.overline)
        .foregroundStyle(Palette.muted)
      Spacer(minLength: 0)
      if case .usage(let usage) = model.state(of: agent) {
        Text(model.ageText(for: usage))
          .typeStyle(.captionSmall)
          .foregroundStyle(Palette.muted)
      }
    }
  }

  private func windowRow(_ window: UsageWindow, of usage: AgentUsage) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: Metrics.Control.compactSpacing) {
        Text(LimitsViewModel.title(for: window))
          .typeStyle(.listRow)
          .foregroundStyle(Palette.fg)
        Text(model.resetText(for: window))
          .typeStyle(.metadata)
          .foregroundStyle(Palette.muted)
        Spacer(minLength: 0)
        Text(model.percentText(for: window))
          .typeStyle(.caption)
          .foregroundStyle(model.isNearLimit(window) ? Palette.danger : Palette.fg2)
      }
      UsageBar(
        fraction: model.fraction(of: window),
        color: model.isNearLimit(window) ? Palette.danger : usage.agent.color
      )
      .padding(.top, Metrics.Limits.barTopPadding)

      if let forecast = model.forecastText(for: window, of: usage) {
        Text(forecast)
          .typeStyle(.metadata)
          .foregroundStyle(model.runsOut(window, of: usage) ? Palette.danger : Palette.muted)
          .padding(.top, Metrics.Limits.forecastTopPadding)
      }
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Перечитывание

  private var footer: some View {
    HStack(spacing: Metrics.Control.compactSpacing) {
      Text("Агенты обновляют лимиты, только пока работают")
        .typeStyle(.metadata)
        .foregroundStyle(Palette.muted)
      Spacer(minLength: 0)
      IconButton(
        systemImage: "arrow.clockwise",
        label: "Перечитать лимиты",
        isConfirming: model.isRefreshConfirmed
      ) {
        Task { await model.refreshNow() }
      }
    }
  }

  // MARK: - Пустые состояния

  private func folderRequest(for agent: Agent) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Не найдена папка \(agent.folderTitle) — \(agent.title) не установлен?")
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.fg2)
      actionButton("Проверить снова") {
        Task { await model.requestAccess(for: agent) }
      }
      .padding(.top, Metrics.Limits.noteTopPadding)
    }
  }

  @ViewBuilder private func noData(for agent: Agent) -> some View {
    switch agent {
    case .claudeCode:
      VStack(alignment: .leading, spacing: 0) {
        Text("Нет данных: claude не ответил на запрос лимитов")
          .typeStyle(.cardTitle)
          .foregroundStyle(Palette.fg2)
        Text(
          "Проверьте вход в Claude Code. Запасной источник — statusLine: вставьте настройку в ~/.claude/settings.json, она заменит текущую строку состояния"
        )
        .typeStyle(.metadata)
        .foregroundStyle(Palette.muted)
        .padding(.top, Metrics.Limits.noteTopPadding)
        actionButton("Скопировать настройку") {
          Task { await model.copyClaudeSetup() }
        }
        .padding(.top, Metrics.Limits.noteTopPadding)
      }
    case .codex:
      Text("Нет данных. Codex запишет лимиты на первом ходу сессии")
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.fg2)
    }
  }

  /// Вторичная кнопка: агентов двое, и две акцентные кнопки дали бы лишние пятна.
  private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .typeStyle(.button)
        .foregroundStyle(Palette.fg)
        .padding(.horizontal, Metrics.Control.primaryHorizontalPadding)
        .frame(minHeight: Metrics.Control.compactHeight)
        .background(Fill.swapButton, in: .rect(cornerRadius: Metrics.Radius.small))
        .overlay {
          RoundedRectangle(cornerRadius: Metrics.Radius.small)
            .stroke(Palette.border, lineWidth: Metrics.hairline)
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

/// Полоса расхода окна.
private struct UsageBar: View {

  let fraction: Double
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Fill.sliderTrack)
        Capsule()
          .fill(color)
          .frame(width: proxy.size.width * fraction)
      }
    }
    .frame(height: Metrics.Limits.barHeight)
    .accessibilityHidden(true)
  }
}
