import FlowbarDesignSystem
import FlowbarDomain
import FlowbarPresentation
import SwiftUI

/// Экран перевода.
struct TranslateView: View {

  /// Пауза перед установкой фокуса.
  ///
  /// Сразу после появления вью SwiftUI ещё не построил цепочку ответчиков, и запрос
  /// фокуса теряется молча. Величина подобрана экспериментально: 120 мс — примерно
  /// семь кадров, с запасом переживает и медленный первый кадр после разворота.
  private static let focusDelay: Duration = .milliseconds(120)

  @Bindable var model: TranslateViewModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isInputFocused: Bool
  @State private var isSwapHovering = false
  @State private var handledFocusRequests = 0

  var body: some View {
    HStack(spacing: Metrics.Translate.paneSpacing) {
      sourcePane
      swapButton
      targetPane
    }
    // `task(id:)`, а не `onChange`: вью создаётся уже после запроса фокуса — модуль
    // переключается тем же сочетанием, — и изменения значения она бы не увидела.
    .task(id: model.focusRequests) {
      guard model.focusRequests != handledFocusRequests else { return }
      handledFocusRequests = model.focusRequests
      try? await Task.sleep(for: Self.focusDelay)
      isInputFocused = true
    }
  }

  // MARK: - Исходная панель

  private var sourcePane: some View {
    pane {
      head {
        sourceLanguagePicker
        Text(detectedTitle)
          .typeStyle(.captionSmall)
          .foregroundStyle(Palette.muted)
      }
      TextEditor(text: $model.sourceText)
        .focused($isInputFocused)
        .scrollContentBackground(.hidden)
        .typeStyle(.translationField)
        .foregroundStyle(Palette.fg)
        .padding(.vertical, Metrics.Translate.editorVerticalPadding)
        .accessibilityLabel("Исходный текст")
      foot {
        Text("\(model.sourceText.count) / \(TranslateViewModel.inputLimit)")
          .typeStyle(.monoCaption)
          .foregroundStyle(Palette.muted)
        Spacer(minLength: 0)
        Button("Вставить") { Task { await model.pasteFromPasteboard() } }
          .buttonStyle(.plain)
          .typeStyle(.captionSmall)
          .foregroundStyle(Palette.fg2)
          .accessibilityLabel("Вставить текст из буфера обмена")
        Button("Очистить") { model.clear() }
          .buttonStyle(.plain)
          .typeStyle(.captionSmall)
          .foregroundStyle(Palette.muted)
      }
    }
  }

  // MARK: - Панель перевода

  private var targetPane: some View {
    pane {
      head {
        targetLanguagePicker
        Text(model.status.title)
          .typeStyle(.captionSmall)
          .foregroundStyle(model.status == .done ? Palette.fg : Palette.muted)
      }
      ScrollView {
        Text(model.translatedText)
          .typeStyle(.translationField)
          .foregroundStyle(Palette.fg2)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, Metrics.Translate.editorVerticalPadding)
      foot {
        Spacer(minLength: 0)
        Button("Скопировать") { Task { await model.copyTranslation() } }
          .buttonStyle(.plain)
          .typeStyle(.captionSmall)
          .foregroundStyle(model.translatedText.isEmpty ? Palette.muted : Palette.fg2)
          .disabled(model.translatedText.isEmpty)
      }
    }
  }

  // MARK: - Сборка панели

  private func pane<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      content()
    }
    .padding(.vertical, Metrics.Translate.panePaddingVertical)
    .padding(.horizontal, Metrics.Translate.panePaddingHorizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .overlay {
      RoundedRectangle(cornerRadius: Metrics.Radius.large)
        .stroke(Palette.borderSoft, lineWidth: Metrics.hairline)
    }
  }

  private func head<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: Metrics.Translate.headBottomPadding) {
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, Metrics.Translate.headBottomPadding)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Palette.borderSoft).frame(height: Metrics.hairline)
    }
  }

  private func foot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: Metrics.Translate.headBottomPadding) {
      content()
    }
    .padding(.top, Metrics.Translate.footTopPadding)
    .overlay(alignment: .top) {
      Rectangle().fill(Palette.borderSoft).frame(height: Metrics.hairline)
    }
  }

  // MARK: - Контролы

  private var sourceLanguagePicker: some View {
    Menu {
      Button("Определить") { model.sourceLanguage = nil }
      ForEach(Language.offered, id: \.self) { language in
        Button(language.title) { model.sourceLanguage = language }
      }
    } label: {
      languageLabel(model.sourceLanguage?.title ?? "Определить")
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .accessibilityLabel("Исходный язык")
  }

  private var targetLanguagePicker: some View {
    Menu {
      ForEach(Language.offered, id: \.self) { language in
        Button(language.title) { model.targetLanguage = language }
      }
    } label: {
      languageLabel(model.targetLanguage.title)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .accessibilityLabel("Язык перевода")
  }

  private func languageLabel(_ title: String) -> some View {
    Text(title)
      .typeStyle(.language)
      .foregroundStyle(Palette.fg)
  }

  private var swapButton: some View {
    Button {
      model.swapLanguages()
    } label: {
      Image(systemName: "arrow.left.arrow.right")
        .foregroundStyle(isSwapHovering ? Palette.fg : Palette.fg2)
        .frame(width: Metrics.Control.button, height: Metrics.Control.button)
        .background(isSwapHovering ? Fill.pressed : Fill.swapButton, in: .circle)
        .overlay { Circle().stroke(Palette.border, lineWidth: Metrics.hairline) }
    }
    .buttonStyle(.plain)
    .onHover { isSwapHovering = $0 }
    .animation(Motion.fast(reduceMotion: reduceMotion), value: isSwapHovering)
    .frame(width: Metrics.Translate.swapColumnWidth)
    .accessibilityLabel("Поменять языки местами")
  }

  private var detectedTitle: String {
    guard model.sourceLanguage == nil, let detected = model.detectedLanguage else { return "" }
    return "определён \(detected.title)"
  }
}
