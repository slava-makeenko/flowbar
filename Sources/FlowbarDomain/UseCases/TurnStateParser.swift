import Foundation

/// Разбор последнего маркера хода в хвосте транскрипта. ADR-0014.
///
/// Служебные строки, которые агенты дописывают после конца хода, маркерами не считаются:
/// иначе каждая из них выглядела бы как работа.
public enum TurnStateParser {

  /// Сколько байт с конца транскрипта читать. Маркер хода — в последних строках, а строка
  /// длиннее хвоста встречается только с огромным выводом инструмента.
  public static let tailLength = 128 * 1024

  /// Последний маркер хода Claude Code.
  /// - Parameter tail: последние строки транскрипта; первая может быть обрезана.
  /// - Returns: состояние хода или `nil`, если маркера в хвосте нет.
  public static func claude(tail: String) -> TurnState? {
    for object in objects(inReversed: tail) {
      switch object["type"] as? String {
      case "user":
        return .working
      case "assistant":
        let message = object["message"] as? [String: Any]
        switch message?["stop_reason"] as? String {
        case "end_turn", "stop_sequence": return .waiting
        default: return .working
        }
      case "system":
        switch object["subtype"] as? String {
        case "turn_duration", "stop_hook_summary": return .waiting
        default: continue
        }
      default:
        continue
      }
    }
    return nil
  }

  /// Последний маркер хода Codex.
  /// - Parameter tail: последние строки rollout-файла; первая может быть обрезана.
  /// - Returns: состояние хода или `nil`, если маркера в хвосте нет.
  public static func codex(tail: String) -> TurnState? {
    for object in objects(inReversed: tail) where object["type"] as? String == "event_msg" {
      switch (object["payload"] as? [String: Any])?["type"] as? String {
      case "task_started": return .working
      case "task_complete", "turn_aborted": return .waiting
      default: continue
      }
    }
    return nil
  }

  /// Принадлежит ли rollout-файл Codex субагенту.
  /// - Parameter firstLine: первая строка файла — `session_meta`.
  /// - Returns: `true`, если в `payload.source` указан субагент.
  public static func isCodexSubagent(sessionMeta firstLine: String) -> Bool {
    guard
      let object = try? JSONSerialization.jsonObject(with: Data(firstLine.utf8)),
      let payload = (object as? [String: Any])?["payload"] as? [String: Any],
      let source = payload["source"] as? [String: Any]
    else { return false }
    return source["subagent"] != nil
  }

  /// Строки хвоста с конца, уже разобранные. Неразборчивые пропускаются.
  private static func objects(inReversed tail: String) -> some Sequence<[String: Any]> {
    tail.split(whereSeparator: \.isNewline).reversed().lazy.compactMap { line in
      (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
    }
  }
}
