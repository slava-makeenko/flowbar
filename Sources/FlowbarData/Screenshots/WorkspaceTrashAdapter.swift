import AppKit
import FlowbarDomain

/// Удаление файла в Корзину.
public struct WorkspaceTrashAdapter: FileTrashing {

  /// Создаёт адаптер.
  public init() {}

  /// Перемещает файл в Корзину.
  ///
  /// Именно `recycle`, а не `removeItem`: пользователь удаляет свой файл, который
  /// приложение не создавало, и должен иметь возможность передумать.
  /// - Parameter url: путь к файлу.
  /// - Returns: `true`, если файл перемещён.
  public func trash(_ url: URL) async -> Bool {
    await withCheckedContinuation { continuation in
      NSWorkspace.shared.recycle([url]) { _, error in
        continuation.resume(returning: error == nil)
      }
    }
  }
}
