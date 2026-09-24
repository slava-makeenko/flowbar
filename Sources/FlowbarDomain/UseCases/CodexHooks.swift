import Foundation

/// Хуки Flowbar в `~/.codex/hooks.json`. ADR-0017.
///
/// Codex держит rollout-файл открытым всю сессию, и FSEvents записей в него не видит.
/// Хук же на каждое событие хода открывает, пишет и закрывает маленький файл — это видно.
/// Установка только добавляет свои хуки: чужие не трогаются, повторная ничего не меняет.
public enum CodexHooks {

  /// События, на которые ставится хук: начало хода, инструменты, конец хода.
  public static let events = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop"]

  /// Каталог внутри `~/.codex`, куда хук пишет события.
  public static let eventsDirectory = "flowbar"

  /// Признак хука Flowbar в команде.
  static let marker = "/.codex/flowbar"

  /// Сколько Codex ждёт хук. Команда — чтение stdin и запись файла, миллисекунды.
  static let timeout = 5

  /// Команда хука: сохраняет полученный JSON в `~/.codex/flowbar/<session_id>.json`.
  ///
  /// Ничего не печатает: вывод хука `UserPromptSubmit` попал бы в контекст модели.
  /// Идентификатор сессии проверяется до записи — он становится именем файла.
  public static let command = #"""
    in=$(cat); id=$(printf '%s' "$in" | /usr/bin/plutil -extract session_id raw -o - - 2>/dev/null) || exit 0; case "$id" in ''|*[!A-Za-z0-9-]*) exit 0 ;; esac; mkdir -p "$HOME/.codex/flowbar" && printf '%s' "$in" > "$HOME/.codex/flowbar/$id.json"; exit 0
    """#

  /// Стоят ли хуки Flowbar на всех нужных событиях.
  /// - Parameter config: содержимое `hooks.json`.
  /// - Returns: `true`, если ставить нечего.
  public static func isInstalled(in config: [String: Any]) -> Bool {
    let hooks = config["hooks"] as? [String: Any] ?? [:]
    return events.allSatisfy { hasFlowbarHook(in: hooks[$0]) }
  }

  /// Добавляет недостающие хуки Flowbar.
  /// - Parameter config: содержимое `hooks.json`.
  /// - Returns: конфиг с хуками Flowbar; чужие хуки и ключи сохранены.
  public static func installing(into config: [String: Any]) -> [String: Any] {
    var config = config
    var hooks = config["hooks"] as? [String: Any] ?? [:]
    for event in events where !hasFlowbarHook(in: hooks[event]) {
      var groups = hooks[event] as? [[String: Any]] ?? []
      groups.append([
        "hooks": [["type": "command", "command": command, "timeout": timeout]]
      ])
      hooks[event] = groups
    }
    config["hooks"] = hooks
    return config
  }

  private static func hasFlowbarHook(in groups: Any?) -> Bool {
    guard let groups = groups as? [[String: Any]] else { return false }
    return groups.contains { group in
      (group["hooks"] as? [[String: Any]] ?? []).contains {
        ($0["command"] as? String)?.contains(marker) == true
      }
    }
  }
}
