import FlowbarDesignSystem
import FlowbarDomain
import FlowbarPresentation
import SwiftUI

/// Экран ленты снимков экрана.
struct ScreenshotsView: View {

  @Bindable var model: ScreenshotsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      switch model.access {
      case .needed: permissionRequest
      case .granted: strip
      }
      Spacer(minLength: 0)
      captureHints
    }
    .task { await model.start() }
  }

  // MARK: - Разрешение

  private var permissionRequest: some View {
    VStack(spacing: Metrics.Screenshots.captionTopPadding) {
      Text("Flowbar не видит папку со снимками")
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.fg2)
      Text("Выберите её один раз — дальше лента будет обновляться сама")
        .typeStyle(.metadata)
        .foregroundStyle(Palette.muted)
      Button("Выбрать папку") {
        Task { await model.requestAccess() }
      }
      .buttonStyle(.plain)
      .typeStyle(.button)
      .foregroundStyle(Palette.accentOn)
      .padding(.horizontal, Metrics.Control.primaryHorizontalPadding)
      .frame(minHeight: Metrics.Control.compactHeight)
      .background(Palette.accent, in: .rect(cornerRadius: Metrics.Radius.small))
      .padding(.top, Metrics.Screenshots.metaTopPadding)
    }
    .frame(maxWidth: .infinity)
    .frame(height: Metrics.Screenshots.emptyHeight)
  }

  // MARK: - Лента

  @ViewBuilder private var strip: some View {
    if model.screenshots.isEmpty {
      Text("Снимков пока нет")
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.Screenshots.emptyHeight)
    } else {
      ScrollView(.horizontal) {
        HStack(spacing: Metrics.Row.cardSpacing) {
          ForEach(model.screenshots) { screenshot in
            ShotCard(model: model, screenshot: screenshot)
          }
        }
      }
      .scrollIndicators(.automatic)
    }
  }

  // MARK: - Шорткаты захвата

  private var captureHints: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("СДЕЛАТЬ СНИМОК")
        .typeStyle(.overline)
        .foregroundStyle(Palette.muted)
        .padding(.bottom, Metrics.Screenshots.hintsLabelBottomPadding)

      VStack(spacing: Metrics.Row.listSpacing) {
        hint("⇧⌘4", "выделенная область")
        hint("⇧⌘3", "весь экран")
        hint("⇧⌘5", "панель захвата")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, Metrics.Screenshots.hintsTopPadding)
    .overlay(alignment: .top) {
      Rectangle().fill(Palette.borderSoft).frame(height: Metrics.hairline)
    }
  }

  private func hint(_ keys: String, _ title: String) -> some View {
    HStack(spacing: Metrics.Screenshots.hintSpacing) {
      KeyChip(keys: keys)
      Text(title)
        .typeStyle(.cardTitle)
        .foregroundStyle(Palette.fg2)
      Spacer(minLength: 0)
    }
    .frame(minHeight: Metrics.Screenshots.hintRowHeight)
  }
}

/// Карточка снимка.
private struct ShotCard: View {

  let model: ScreenshotsViewModel
  let screenshot: Screenshot

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isHovering = false
  @FocusState private var isFocused: Bool

  var body: some View {
    // Крестик — сосед карточки, а не наложение поверх неё: вложенная в кнопку кнопка
    // не получает нажатие, внешняя перехватывает его целиком.
    ZStack(alignment: .topTrailing) {
      Button {
        Task { await model.copy(screenshot) }
      } label: {
        VStack(alignment: .leading, spacing: 0) {
          preview
          meta
        }
        .padding(Metrics.Row.cardPadding)
        .frame(width: Metrics.Row.cardWidth)
        .background(
          isHovering ? Fill.cardHover : Fill.rest,
          in: .rect(cornerRadius: Metrics.Radius.medium)
        )
        .overlay {
          RoundedRectangle(cornerRadius: Metrics.Radius.medium)
            .stroke(borderColor, lineWidth: Metrics.hairline)
        }
      }
      .buttonStyle(.plain)
      .focused($isFocused)
      .accessibilityLabel("Скопировать снимок \(screenshot.name)")

      deleteButton
    }
    .onHover { isHovering = $0 }
    .animation(Motion.fast(reduceMotion: reduceMotion), value: isHovering)
  }

  @ViewBuilder private var preview: some View {
    if let data = model.thumbnails[screenshot.id], let image = NSImage(data: data) {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(height: Metrics.Row.cardThumbnailHeight)
        .clipShape(.rect(cornerRadius: Metrics.Radius.chip))
    } else {
      Rectangle()
        .fill(Fill.typeBadge)
        .frame(height: Metrics.Row.cardThumbnailHeight)
        .clipShape(.rect(cornerRadius: Metrics.Radius.chip))
    }
  }

  private var meta: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: Metrics.Control.compactSpacing) {
        Text(screenshot.name)
          .typeStyle(.cardTitle)
          .foregroundStyle(Palette.fg2)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: 0)
        Text(model.moment(for: screenshot))
          .typeStyle(.captionSmall)
          .foregroundStyle(Palette.muted)
          .fixedSize()
      }
      .padding(.top, Metrics.Screenshots.metaTopPadding)

      Text(model.caption(for: screenshot))
        .typeStyle(.monoCaption)
        .foregroundStyle(Palette.muted)
        .padding(.top, Metrics.Screenshots.captionTopPadding)
    }
  }

  /// Крестик появляется по наведению **и по фокусу**: иначе снимок нельзя удалить
  /// с клавиатуры.
  @ViewBuilder private var deleteButton: some View {
    if isHovering || isFocused {
      Button {
        Task { await model.delete(screenshot) }
      } label: {
        Image(systemName: "xmark")
          .foregroundStyle(Palette.fg2)
          .frame(width: Metrics.Control.deleteButton, height: Metrics.Control.deleteButton)
          .background(Palette.bgNotched.opacity(0.78), in: .circle)
          .overlay { Circle().stroke(Palette.border, lineWidth: Metrics.hairline) }
      }
      .buttonStyle(.plain)
      .padding(Metrics.Control.deleteButtonInset)
      .accessibilityLabel("Удалить снимок \(screenshot.name)")
    }
  }

  private var borderColor: Color {
    if model.confirmedItem == screenshot.id.path { return Palette.success }
    return isHovering ? Palette.border : Palette.borderSoft
  }
}
