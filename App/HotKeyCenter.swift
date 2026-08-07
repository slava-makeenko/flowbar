import AppKit
import Carbon.HIToolbox

/// Глобальные сочетания клавиш.
///
/// Carbon `RegisterEventHotKey` выбран не из ностальгии: он не требует разрешения
/// Accessibility, в отличие от `CGEventTap`. API старое, но не депрекейтнутое и остаётся
/// штатным способом регистрации глобальных сочетаний.
@MainActor
final class HotKeyCenter {

  /// Сочетание клавиш.
  struct Shortcut {

    /// Код клавиши в терминах Carbon.
    let key: Int

    /// Маска модификаторов в терминах Carbon.
    let modifiers: Int

    /// ⌥Space — развернуть или свернуть панель.
    static let toggle = Shortcut(key: kVK_Space, modifiers: optionKey)

    /// ⌘⇧V — открыть буфер обмена.
    static let clipboard = Shortcut(key: kVK_ANSI_V, modifiers: cmdKey | shiftKey)

    /// ⌥T — открыть перевод.
    static let translate = Shortcut(key: kVK_ANSI_T, modifiers: optionKey)
  }

  /// Действия по идентификатору сочетания.
  ///
  /// Обработчик Carbon — сишная функция без контекста, поэтому таблица статическая.
  /// Обращение к ней происходит только на главном потоке: события горячих клавиш
  /// доставляются именно туда.
  private nonisolated(unsafe) static var actions: [UInt32: @MainActor () -> Void] = [:]

  private var registered: [EventHotKeyRef] = []
  private var handler: EventHandlerRef?
  private var nextIdentifier: UInt32 = 1

  /// Регистрирует сочетание.
  /// - Parameters:
  ///   - shortcut: сочетание.
  ///   - action: что делать при нажатии.
  func register(_ shortcut: Shortcut, action: @escaping @MainActor () -> Void) {
    installHandlerIfNeeded()

    let identifier = nextIdentifier
    nextIdentifier += 1
    Self.actions[identifier] = action

    var reference: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(shortcut.key),
      UInt32(shortcut.modifiers),
      EventHotKeyID(signature: Self.signature, id: identifier),
      GetApplicationEventTarget(),
      0,
      &reference
    )
    if status == noErr, let reference {
      registered.append(reference)
    } else {
      Self.actions[identifier] = nil
    }
  }

  /// Снимает все регистрации.
  func unregisterAll() {
    registered.forEach { UnregisterEventHotKey($0) }
    registered = []
    Self.actions = [:]
    if let handler { RemoveEventHandler(handler) }
    handler = nil
  }

  private func installHandlerIfNeeded() {
    guard handler == nil else { return }
    var specification = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, _ in
        var identifier = EventHotKeyID()
        GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &identifier
        )
        MainActor.assumeIsolated { HotKeyCenter.actions[identifier.id]?() }
        return noErr
      },
      1,
      &specification,
      nil,
      &handler
    )
  }

  /// Подпись приложения в идентификаторе сочетания: `flwb`.
  private static let signature: OSType = 0x666C_7762
}
