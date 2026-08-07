import SwiftUI

/// Строка списка: сетка `34 / 1fr / auto` с зазором 12.
///
/// Одна и та же в истории копирований и в быстрых вставках — регламент §6 называет её
/// целью для выноса. Различаются только высота и содержимое.
public struct ListRow<Trailing: View>: View {

  private let systemImage: String
  private let title: String
  private let isTitleMonospaced: Bool
  private let metaLead: String
  private let metaRest: String
  private let minimumHeight: CGFloat
  private let trailing: () -> Trailing

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var isHovering = false

  /// Создаёт строку списка.
  /// - Parameters:
  ///   - systemImage: символ вида содержимого.
  ///   - title: основная строка; обрезается многоточием.
  ///   - isTitleMonospaced: набирать ли основную строку моноширинным.
  ///   - metaLead: первая часть подписи — вид содержимого, набирается светлее.
  ///   - metaRest: остаток подписи: источник и время.
  ///   - minimumHeight: высота строки.
  ///   - trailing: контролы справа.
  public init(
    systemImage: String,
    title: String,
    isTitleMonospaced: Bool = false,
    metaLead: String,
    metaRest: String,
    minimumHeight: CGFloat,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.systemImage = systemImage
    self.title = title
    self.isTitleMonospaced = isTitleMonospaced
    self.metaLead = metaLead
    self.metaRest = metaRest
    self.minimumHeight = minimumHeight
    self.trailing = trailing
  }

  /// Содержимое вью.
  public var body: some View {
    HStack(spacing: Metrics.Row.columnSpacing) {
      badge
      main
      trailing()
    }
    .padding(.top, Metrics.Row.insets.top)
    .padding(.leading, Metrics.Row.insets.leading)
    .padding(.bottom, Metrics.Row.insets.bottom)
    .padding(.trailing, Metrics.Row.insets.trailing)
    .frame(minHeight: minimumHeight)
    .background(
      isHovering ? Fill.rowHover : Fill.rest, in: .rect(cornerRadius: Metrics.Radius.medium)
    )
    .overlay {
      RoundedRectangle(cornerRadius: Metrics.Radius.medium)
        .stroke(isHovering ? borderColor : .clear, lineWidth: 1)
    }
    .contentShape(.rect)
    .onHover { isHovering = $0 }
    .animation(Motion.fast(reduceMotion: reduceMotion), value: isHovering)
  }

  private var badge: some View {
    Image(systemName: systemImage)
      .foregroundStyle(Palette.fg2)
      .frame(width: Metrics.Control.typeBadge, height: Metrics.Control.typeBadge)
      .background(Fill.typeBadge, in: .rect(cornerRadius: Metrics.Radius.small))
  }

  private var main: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .typeStyle(isTitleMonospaced ? .monoTitle : .listRow)
        .foregroundStyle(Palette.fg)
        .lineLimit(1)
        .truncationMode(.tail)
      HStack(spacing: 0) {
        Text(metaLead).foregroundStyle(Palette.fg2)
        Text(metaRest).foregroundStyle(Palette.muted)
      }
      .typeStyle(.metadata)
      .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var borderColor: Color {
    Palette.borderSoft(increasedContrast: contrast == .increased)
  }
}

extension TypeStyle {

  /// Основная строка списка моноширинным — путь, цвет, хеш.
  public static let monoTitle = TypeStyle(size: 12, weight: 510, isMonospaced: true)
}
