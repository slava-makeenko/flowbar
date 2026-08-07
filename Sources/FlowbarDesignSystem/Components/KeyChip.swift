import SwiftUI

/// Чип с сочетанием клавиш.
public struct KeyChip: View {

  private let keys: String

  @Environment(\.colorSchemeContrast) private var contrast

  /// Создаёт чип.
  /// - Parameter keys: сочетание, например `⇧⌘4`.
  public init(keys: String) {
    self.keys = keys
  }

  /// Содержимое вью.
  public var body: some View {
    Text(keys)
      .typeStyle(.keyChip)
      .foregroundStyle(Palette.fg)
      .padding(.horizontal, 10)
      .frame(
        minWidth: Metrics.Control.keyChipMinimumWidth,
        minHeight: Metrics.Control.keyChipHeight
      )
      .overlay {
        RoundedRectangle(cornerRadius: Metrics.Radius.chip)
          .stroke(Palette.border(increasedContrast: contrast == .increased), lineWidth: 1)
      }
  }
}
