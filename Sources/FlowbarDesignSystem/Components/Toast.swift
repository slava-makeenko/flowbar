import SwiftUI

/// Всплывающее подтверждение действия.
///
/// Размещение задаёт вызывающая сторона: тост появляется внутри панели, а не в окне
/// рабочего стола, как в прототипе.
public struct Toast: View {

  private let message: String

  /// Создаёт тост.
  /// - Parameter message: текст подтверждения.
  public init(message: String) {
    self.message = message
  }

  /// Содержимое вью.
  public var body: some View {
    Text(message)
      .typeStyle(.caption)
      .foregroundStyle(Palette.fg)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(minWidth: 190)
      .background(Palette.surface, in: .rect(cornerRadius: Metrics.Radius.medium))
      .overlay {
        RoundedRectangle(cornerRadius: Metrics.Radius.medium)
          .stroke(Palette.border, lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
      // Тост озвучивается как объявление: без этого результат копирования в VoiceOver
      // не сообщается вообще.
      .accessibilityAddTraits(.updatesFrequently)
      .accessibilityLabel(message)
  }
}
