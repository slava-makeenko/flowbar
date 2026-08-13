import FlowbarDesignSystem
import FlowbarDomain
import FlowbarPresentation
import SwiftUI

/// Экран истории копирований.
struct ClipboardView: View {

  @Bindable var model: ClipboardViewModel

  var body: some View {
    // Загрузка висит на внешнем вью, а не на списке: список рисуется только когда
    // история уже непустая, и `.task` на нём никогда бы не запустился после перезапуска.
    content.task { await model.load() }
  }

  @ViewBuilder private var content: some View {
    if model.clips.isEmpty {
      Text("История пуста — скопируйте что-нибудь")
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(spacing: Metrics.Row.listSpacing) {
          ForEach(model.clips) { clip in
            row(for: clip)
          }
        }
      }
    }
  }

  private func row(for clip: ClipItem) -> some View {
    ListRow(
      systemImage: clip.kind.systemImage,
      title: model.title(for: clip),
      isTitleMonospaced: clip.kind.prefersMonospacedPreview,
      metaLead: clip.kind.title,
      metaRest: model.caption(for: clip),
      minimumHeight: Metrics.Row.clipHeight
    ) {
      IconButton(
        systemImage: "square.on.square",
        label: "Скопировать \(clip.kind.title.lowercased())",
        isConfirming: model.confirmingItem == clip.id.uuidString
      ) {
        Task { await model.copy(clip) }
      }
    }
  }
}

extension ClipKind {

  /// Символ вида копии.
  var systemImage: String {
    switch self {
    case .text: "doc.text"
    case .link: "link"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .image: "photo"
    case .color: "paintpalette"
    case .address: "mappin.and.ellipse"
    case .path: "folder"
    case .value: "number.square"
    case .email: "envelope"
    }
  }
}
