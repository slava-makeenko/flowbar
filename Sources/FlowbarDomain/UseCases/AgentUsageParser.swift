import Foundation

/// Разбор снимков лимитов из файлов агентов.
///
/// Оба формата внутренние и никем не обещаны, поэтому разбор терпимый: неизвестный ключ,
/// `null` или пропавшее поле убирают одно окно, а не весь снимок. ADR-0012.
public enum AgentUsageParser {

  /// Сессионное окно Claude Code — пять часов.
  static let fiveHours: TimeInterval = 5 * 60 * 60

  /// Недельное окно Claude Code.
  static let sevenDays: TimeInterval = 7 * 24 * 60 * 60

  /// Сколько байт с конца rollout-файла Codex достаточно, чтобы найти последний снимок.
  ///
  /// Codex пишет `rate_limits` на каждом ходу, а ход редко длиннее сотни килобайт.
  public static let codexTailLength = 256 * 1024

  /// Находит последний снимок в хвосте rollout-файла Codex.
  ///
  /// Снимки без единого окна пропускаются: у team-аккаунта в том же файле встречаются
  /// записи с `primary: null`, и они не должны перекрывать настоящие данные.
  /// - Parameter tail: последние строки файла; первая может быть обрезана.
  /// - Returns: снимок или `nil`, если в хвосте его нет.
  public static func codex(tail: String) -> AgentUsage? {
    for line in tail.split(whereSeparator: \.isNewline).reversed()
    where line.contains("\"rate_limits\"") {
      guard
        let object = json(Data(line.utf8)),
        let payload = object["payload"] as? [String: Any],
        let limits = payload["rate_limits"] as? [String: Any],
        let timestamp = object["timestamp"] as? String,
        let measuredAt = date(iso8601: timestamp)
      else { continue }

      let windows = ["primary", "secondary"].compactMap { key in
        codexWindow(limits[key] as? [String: Any])
      }
      if !windows.isEmpty {
        return AgentUsage(agent: .codex, windows: windows, measuredAt: measuredAt)
      }
    }
    return nil
  }

  /// Разбирает снимок, который statusLine-скрипт сохранил из payload Claude Code.
  /// - Parameters:
  ///   - snapshot: содержимое `rate_limits` из payload.
  ///   - measuredAt: момент записи файла.
  /// - Returns: снимок или `nil`, если окон нет.
  public static func claude(snapshot: Data, measuredAt: Date) -> AgentUsage? {
    guard let limits = json(snapshot) else { return nil }
    let windows = [("five_hour", fiveHours), ("seven_day", sevenDays)].compactMap {
      key, duration in
      claudeWindow(limits[key] as? [String: Any], duration: duration)
    }
    guard !windows.isEmpty else { return nil }
    return AgentUsage(agent: .claudeCode, windows: windows, measuredAt: measuredAt)
  }

  // MARK: - Окна

  private static func codexWindow(_ object: [String: Any]?) -> UsageWindow? {
    guard
      let object,
      let used = number(object["used_percent"]),
      let minutes = number(object["window_minutes"]), minutes > 0,
      let resets = number(object["resets_at"])
    else { return nil }
    return UsageWindow(
      duration: minutes * 60,
      usedPercent: used,
      resetsAt: Date(timeIntervalSince1970: resets)
    )
  }

  private static func claudeWindow(
    _ object: [String: Any]?,
    duration: TimeInterval
  ) -> UsageWindow? {
    guard
      let object,
      let used = number(object["used_percentage"]),
      let resets = number(object["resets_at"])
    else { return nil }
    return UsageWindow(
      duration: duration,
      usedPercent: used,
      resetsAt: Date(timeIntervalSince1970: resets)
    )
  }

  // MARK: - JSON

  private static func json(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  /// Число из JSON. `Bool` отсекается явно: `JSONSerialization` отдаёт его как `NSNumber`.
  private static func number(_ value: Any?) -> Double? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
      return nil
    }
    return number.doubleValue
  }

  private static func date(iso8601 string: String) -> Date? {
    (try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
      ?? (try? Date(string, strategy: .iso8601))
  }
}
