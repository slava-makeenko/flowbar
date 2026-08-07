import Foundation

/// Подтверждение копирования: тост и галочка на кнопке.
///
/// Один тип на три модуля — буфер, снимки и вставки подтверждают копирование одинаково,
/// и расходиться этому поведению незачем. Регламент §6.
///
/// Длительности живут здесь, а не в дизайн-системе: это поведение, а не оформление —
/// они определяют, сколько состояние держится, а не как оно выглядит.
@MainActor
@Observable
public final class CopyFeedback {

  /// Сколько держится галочка вместо иконки копирования.
  public static let confirmationDuration: Duration = .milliseconds(1400)

  /// Сколько держится рамка подтверждения на карточке.
  public static let cardConfirmationDuration: Duration = .milliseconds(900)

  /// Текст тоста; `nil`, когда тост скрыт.
  public private(set) var message: String?

  /// Идентификатор элемента, на кнопке которого сейчас галочка.
  public private(set) var confirmingItem: String?

  private var dismissTask: Task<Void, Never>?

  /// Создаёт подтверждение.
  public init() {}

  /// Показывает подтверждение и сам его убирает.
  /// - Parameters:
  ///   - message: текст тоста.
  ///   - item: идентификатор элемента, чью кнопку нужно пометить галочкой.
  ///   - duration: сколько держится пометка.
  public func confirm(
    _ message: String,
    item: String,
    duration: Duration = CopyFeedback.confirmationDuration
  ) {
    dismissTask?.cancel()
    self.message = message
    confirmingItem = item

    dismissTask = Task { [weak self] in
      try? await Task.sleep(for: duration)
      guard !Task.isCancelled else { return }
      self?.message = nil
      self?.confirmingItem = nil
    }
  }
}
