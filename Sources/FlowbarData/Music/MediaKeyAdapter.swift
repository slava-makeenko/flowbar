import AppKit
import FlowbarDomain

/// Управление воспроизведением системными медиа-клавишами.
///
/// Реализует **только** `PlaybackControlling`: метаданные медиа-клавиши получить не
/// могут физически, и притворяться, что могут, адаптер не должен — регламент §5, ISP.
/// Зато работают с любым приложением, включая браузер.
public struct MediaKeyAdapter: PlaybackControlling {

  private enum Key: Int32 {
    case play = 16
    case next = 17
    case previous = 18
  }

  /// Создаёт адаптер.
  public init() {}

  /// Переключает воспроизведение и паузу.
  public func toggle() async {
    send(.play)
  }

  /// Переходит к следующему треку.
  public func next() async {
    send(.next)
  }

  /// Переходит к предыдущему треку.
  public func previous() async {
    send(.previous)
  }

  private func send(_ key: Key) {
    // Нажатие и отпускание: система ждёт обе половины, иначе клавиша считается зажатой.
    for isDown in [true, false] {
      let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xA00 : 0xB00)
      let data1 = Int((key.rawValue << 16) | ((isDown ? 0xA : 0xB) << 8))
      guard
        let event = NSEvent.otherEvent(
          with: .systemDefined,
          location: .zero,
          modifierFlags: flags,
          timestamp: 0,
          windowNumber: 0,
          context: nil,
          subtype: 8,
          data1: data1,
          data2: -1
        )
      else { continue }
      event.cgEvent?.post(tap: .cghidEventTap)
    }
  }
}
