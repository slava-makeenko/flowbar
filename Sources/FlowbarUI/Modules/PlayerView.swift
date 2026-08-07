import FlowbarDesignSystem
import FlowbarPresentation
import SwiftUI

/// Экран плеера системного аудио.
struct PlayerView: View {

  @Bindable var model: MusicViewModel

  var body: some View {
    VStack(spacing: 0) {
      header
      Spacer(minLength: 0)
      progress
      controls
      volume
    }
    .frame(maxWidth: Metrics.Player.maximumWidth)
    .frame(maxWidth: .infinity)
    .task { await model.observe() }
  }

  // MARK: - Шапка

  private var header: some View {
    HStack(spacing: Metrics.Player.topSpacing) {
      artwork
      VStack(alignment: .leading, spacing: 0) {
        Text(model.sourceTitle)
          .typeStyle(.metadata)
          .foregroundStyle(Palette.muted)
          .padding(.bottom, Metrics.Player.sourceBottomSpacing)

        Text(model.track?.title ?? "Ничего не играет")
          .typeStyle(.trackTitle)
          .foregroundStyle(Palette.fg)
          .lineLimit(2)
          .padding(.bottom, Metrics.Player.titleBottomSpacing)

        Text(model.track?.artist ?? "")
          .typeStyle(.listRow)
          .foregroundStyle(Palette.muted)
          .lineLimit(1)

        if let device = model.outputDevice {
          outputChip(device)
            .padding(.top, Metrics.Player.sourceBottomSpacing)
        }
      }
      Spacer(minLength: 0)
    }
  }

  private var artwork: some View {
    RoundedRectangle(cornerRadius: Metrics.Radius.large)
      .fill(Fill.typeBadge)
      .frame(width: Metrics.Control.albumArt, height: Metrics.Control.albumArt)
      .overlay {
        Image(systemName: "music.note")
          .foregroundStyle(Palette.muted)
      }
      .overlay {
        RoundedRectangle(cornerRadius: Metrics.Radius.large)
          .stroke(Palette.border, lineWidth: Metrics.hairline)
      }
      .accessibilityHidden(true)
  }

  private func outputChip(_ device: String) -> some View {
    HStack(spacing: Metrics.Control.compactSpacing) {
      Image(systemName: "hifispeaker")
      Text(device)
    }
    .typeStyle(.caption)
    .foregroundStyle(Palette.fg2)
    .padding(.horizontal, Metrics.Control.segmentHorizontalPadding)
    .frame(minHeight: Metrics.Control.keyChipHeight)
    .overlay {
      Capsule().stroke(Palette.border, lineWidth: Metrics.hairline)
    }
  }

  // MARK: - Прогресс

  /// Полоса прогресса скрывается, когда позиции нет: показывать нулевой прогресс
  /// значило бы утверждать то, чего источник не сообщал.
  @ViewBuilder private var progress: some View {
    if let position = model.position {
      VStack(spacing: 0) {
        ThinSlider(value: position.elapsed / max(position.duration, 1)) { fraction in
          Task { await model.seek(toFraction: fraction) }
        }
        HStack {
          Text(MusicViewModel.time(position.elapsed))
          Spacer(minLength: 0)
          Text(MusicViewModel.time(position.duration - position.elapsed))
        }
        .typeStyle(.monoCaption)
        .foregroundStyle(Palette.muted)
        .padding(.top, Metrics.Player.timeTopPadding)
      }
      .padding(.top, Metrics.Player.progressTopPadding)
    }
  }

  // MARK: - Транспорт

  private var controls: some View {
    HStack(spacing: Metrics.Player.controlsSpacing) {
      transportButton("backward.fill", label: "Предыдущий трек") {
        await model.previous()
      }
      Button {
        Task { await model.toggle() }
      } label: {
        Image(systemName: "playpause.fill")
          .foregroundStyle(Palette.bgNotched)
          .frame(width: Metrics.Control.playButton, height: Metrics.Control.playButton)
          .background(Palette.fg, in: .circle)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Воспроизведение или пауза")
      transportButton("forward.fill", label: "Следующий трек") {
        await model.next()
      }
    }
    .padding(.top, Metrics.Player.controlsTopPadding)
  }

  private func transportButton(
    _ systemImage: String,
    label: String,
    action: @escaping () async -> Void
  ) -> some View {
    IconButton(systemImage: systemImage, label: label) {
      Task { await action() }
    }
  }

  // MARK: - Громкость

  private var volume: some View {
    HStack(spacing: Metrics.Player.volumeSpacing) {
      Image(systemName: "speaker.fill")
        .frame(width: Metrics.Player.volumeIcon)
      ThinSlider(value: model.volume) { model.volume = $0 }
      Image(systemName: "speaker.wave.3.fill")
        .frame(width: Metrics.Player.volumeIcon)
    }
    .foregroundStyle(Palette.muted)
    .padding(.top, Metrics.Player.controlsTopPadding)
    .accessibilityLabel("Системная громкость")
  }
}

/// Тонкий ползунок: дорожка, заполненная часть и бегунок.
private struct ThinSlider: View {

  let value: Double
  let onChange: (Double) -> Void

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let clamped = min(max(value, 0), 1)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Fill.sliderTrack)
          .frame(height: Metrics.Player.sliderHeight)
        Capsule()
          .fill(Palette.fg)
          .frame(width: width * clamped, height: Metrics.Player.sliderHeight)
        Circle()
          .fill(Palette.fg)
          .frame(width: Metrics.Player.sliderThumb, height: Metrics.Player.sliderThumb)
          .offset(x: width * clamped - Metrics.Player.sliderThumbRadius)
      }
      .frame(height: Metrics.Player.sliderThumb)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { onChange($0.location.x / max(width, 1)) }
      )
    }
    .frame(height: Metrics.Player.sliderThumb)
  }
}
