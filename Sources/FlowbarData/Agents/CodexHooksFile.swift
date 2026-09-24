import FlowbarDomain
import Foundation

/// Хуки Flowbar в `~/.codex/hooks.json`. ADR-0017.
///
/// Прежний конфиг один раз сохраняется рядом как `hooks.json.before-flowbar`. Доверие к хукам
/// Codex спрашивает у пользователя сам — `trusted_hash` в `config.toml` Flowbar не пишет:
/// это была бы попытка обойти его защиту.
public struct CodexHooksFile: CodexHooksInstalling {

  private let config: URL

  /// Создаёт доступ к конфигу.
  /// - Parameter folder: папка Codex.
  public init(folder: URL) {
    self.config = AgentFiles.codexHooksConfig(in: folder)
  }

  /// Стоят ли хуки Flowbar на всех нужных событиях.
  public var isInstalled: Bool {
    get async { CodexHooks.isInstalled(in: read() ?? [:]) }
  }

  /// Ставит недостающие хуки.
  /// - Returns: `true`, если после вызова хуки стоят.
  @discardableResult
  public func install() async -> Bool {
    let fileManager = FileManager.default
    let exists = fileManager.fileExists(atPath: config.path)
    // Конфиг, который не разбирается, не перезаписываем: в нём чужие хуки.
    guard let current = exists ? read() : [:] else { return false }
    guard !CodexHooks.isInstalled(in: current) else { return true }

    let backup = config.appendingPathExtension("before-flowbar")
    if exists && !fileManager.fileExists(atPath: backup.path) {
      try? fileManager.copyItem(at: config, to: backup)
    }

    let updated = CodexHooks.installing(into: current)
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: updated,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      ),
      (try? data.write(to: config, options: .atomic)) != nil
    else { return false }
    return CodexHooks.isInstalled(in: read() ?? [:])
  }

  private func read() -> [String: Any]? {
    guard let data = try? Data(contentsOf: config) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }
}
