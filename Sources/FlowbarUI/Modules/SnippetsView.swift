import FlowbarDesignSystem
import FlowbarDomain
import FlowbarPresentation
import SwiftUI

/// Экран быстрых вставок.
struct SnippetsView: View {

  @Bindable var model: SnippetsViewModel

  @FocusState private var isFieldFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      form
        .padding(.bottom, Metrics.Row.formBottomSpacing)
      hint
        .padding(.bottom, Metrics.Row.hintBottomSpacing)
      list
    }
    .task { await model.load() }
  }

  // MARK: - Форма

  private var form: some View {
    HStack(spacing: Metrics.Control.compactSpacing) {
      kindPicker
      field
      addButton
    }
  }

  private var kindPicker: some View {
    HStack(spacing: Metrics.Control.segmentedPadding) {
      ForEach(SnippetKind.allCases, id: \.self) { kind in
        Button {
          model.draftKind = kind
        } label: {
          Text(kind.title)
            .typeStyle(.caption)
            .foregroundStyle(model.draftKind == kind ? Palette.fg : Palette.muted)
            .padding(.horizontal, Metrics.Control.segmentHorizontalPadding)
            .frame(minHeight: Metrics.Control.segmentHeight)
            .background(
              model.draftKind == kind ? Fill.segmentSelected : Fill.rest,
              in: .rect(cornerRadius: Metrics.Radius.segment)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.draftKind == kind ? [.isSelected] : [])
      }
    }
    .padding(Metrics.Control.segmentedPadding)
    .overlay {
      RoundedRectangle(cornerRadius: Metrics.Radius.small)
        .stroke(Palette.borderSoft, lineWidth: Metrics.hairline)
    }
  }

  private var field: some View {
    TextField(model.placeholder, text: $model.draftValue)
      .textFieldStyle(.plain)
      .typeStyle(.listRow)
      .foregroundStyle(Palette.fg)
      .focused($isFieldFocused)
      .onSubmit { Task { await model.add() } }
      .padding(.horizontal, Metrics.Control.fieldHorizontalPadding)
      .frame(minHeight: Metrics.Control.compactHeight)
      .background(
        isFieldFocused ? Fill.fieldFocused : Fill.fieldRest,
        in: .rect(cornerRadius: Metrics.Radius.small)
      )
      .overlay {
        RoundedRectangle(cornerRadius: Metrics.Radius.small)
          .stroke(fieldBorder, lineWidth: Metrics.hairline)
      }
      .accessibilityLabel("Значение вставки")
  }

  private var addButton: some View {
    Button {
      Task { await model.add() }
    } label: {
      Text("Добавить")
        .typeStyle(.button)
        .foregroundStyle(Palette.accentOn)
        .padding(.horizontal, Metrics.Control.primaryHorizontalPadding)
        .frame(minHeight: Metrics.Control.compactHeight)
        .background(Palette.accent, in: .rect(cornerRadius: Metrics.Radius.small))
    }
    .buttonStyle(.plain)
  }

  private var fieldBorder: Color {
    model.errorMessage == nil ? Palette.border : Palette.danger
  }

  @ViewBuilder private var hint: some View {
    if let error = model.errorMessage {
      Text(error)
        .typeStyle(.metadata)
        .foregroundStyle(Palette.danger)
    } else {
      Text("Значение проверяется по виду и добавляется в начало списка")
        .typeStyle(.metadata)
        .foregroundStyle(Palette.muted)
    }
  }

  // MARK: - Список

  @ViewBuilder private var list: some View {
    if model.snippets.isEmpty {
      Text("Пока пусто — добавьте первую вставку")
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.Row.emptyStateVerticalPadding)
    } else {
      ScrollView {
        LazyVStack(spacing: Metrics.Row.listSpacing) {
          ForEach(model.snippets) { snippet in
            row(for: snippet)
          }
        }
      }
      .scrollIndicators(.automatic)
    }
  }

  private func row(for snippet: Snippet) -> some View {
    ListRow(
      systemImage: snippet.kind.systemImage,
      title: snippet.value,
      metaLead: snippet.kind.title,
      metaRest: snippet.note.isEmpty ? "" : " · \(snippet.note)",
      minimumHeight: Metrics.Row.snippetHeight
    ) {
      HStack(spacing: Metrics.Row.actionSpacing) {
        IconButton(
          systemImage: "square.on.square",
          label: "Скопировать \(snippet.kind.title.lowercased())",
          isConfirming: model.confirmingItem == snippet.id.uuidString
        ) {
          Task { await model.copy(snippet) }
        }
        IconButton(
          systemImage: "trash",
          label: "Удалить \(snippet.value)",
          role: .destructive
        ) {
          Task { await model.remove(snippet) }
        }
      }
    }
  }
}

extension SnippetKind {

  /// Символ вида вставки.
  var systemImage: String {
    switch self {
    case .email: "envelope"
    case .tag: "number"
    case .phone: "phone"
    }
  }
}
