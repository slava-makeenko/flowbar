import FlowbarDesignSystem
import FlowbarPresentation
import SwiftUI

/// Экран настроек.
struct SettingsView: View {

  @Bindable var model: SettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Metrics.Settings.sectionSpacing) {
      launchSection
      historySection
      Spacer(minLength: 0)
      version
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .task { await model.load() }
  }

  // MARK: - Запуск

  private var launchSection: some View {
    section("ЗАПУСК") {
      HStack(spacing: 0) {
        Text("Открывать при входе в систему")
          .typeStyle(.listRow)
          .foregroundStyle(Palette.fg)
        Spacer(minLength: 0)
        Toggle(
          "",
          isOn: Binding(
            get: { model.launchesAtLogin },
            set: { enabled in Task { await model.setLaunchesAtLogin(enabled) } }
          )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(Palette.accent)
      }
      .frame(minHeight: Metrics.Settings.rowHeight)
      .accessibilityLabel("Открывать Flowbar при входе в систему")
    }
  }

  // MARK: - История

  private var historySection: some View {
    section("ИСТОРИЯ КОПИРОВАНИЙ") {
      HStack(spacing: Metrics.Control.segmentedPadding) {
        ForEach(SettingsViewModel.offeredLifetimes, id: \.self) { lifetime in
          Button {
            Task { await model.setHistoryLifetime(lifetime) }
          } label: {
            Text(SettingsViewModel.title(for: lifetime))
              .typeStyle(.caption)
              .foregroundStyle(model.historyLifetime == lifetime ? Palette.fg : Palette.muted)
              .padding(.horizontal, Metrics.Control.segmentHorizontalPadding)
              .frame(minHeight: Metrics.Control.segmentHeight)
              .background(
                model.historyLifetime == lifetime ? Fill.segmentSelected : Fill.rest,
                in: .rect(cornerRadius: Metrics.Radius.segment)
              )
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(model.historyLifetime == lifetime ? [.isSelected] : [])
        }
      }
      .padding(Metrics.Control.segmentedPadding)
      .overlay {
        RoundedRectangle(cornerRadius: Metrics.Radius.small)
          .stroke(Palette.borderSoft, lineWidth: Metrics.hairline)
      }

      Text("Записи старше срока удаляются вместе с сохранёнными картинками")
        .typeStyle(.metadata)
        .foregroundStyle(Palette.muted)
        .padding(.top, Metrics.Settings.noteTopPadding)
    }
  }

  // MARK: - Общее

  private func section<Content: View>(
    _ heading: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(heading)
        .typeStyle(.overline)
        .foregroundStyle(Palette.muted)
        .padding(.bottom, Metrics.Settings.headingBottomPadding)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var version: some View {
    Text("Flowbar \(Bundle.main.shortVersion)")
      .typeStyle(.monoCaption)
      .foregroundStyle(Palette.muted)
  }
}

extension Bundle {

  /// Версия приложения из `Info.plist`.
  fileprivate var shortVersion: String {
    object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
  }
}
