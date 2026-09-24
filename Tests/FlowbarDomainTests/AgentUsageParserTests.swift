import FlowbarDomain
import Foundation
import Testing

// Образцы сняты с codex-cli 0.153.4 и Claude Code 2.1.267, 2026-09-23. Если разбор
// сломается после обновления агента, сюда нужно положить свежий образец.

private let codexLine = """
  {"timestamp":"2026-09-22T13:56:02.121Z","ordinal":812,"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1200}},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":96.0,"window_minutes":300,"resets_at":1790093632},"secondary":{"used_percent":39.0,"window_minutes":10080,"resets_at":1790435646},"credits":{"has_credits":false,"unlimited":false,"balance":"0"},"individual_limit":null,"spend_control_reached":null,"plan_type":"plus","rate_limit_reached_type":null}}}
  """

private let codexEmptyLine = """
  {"timestamp":"2026-09-22T13:57:00.000Z","ordinal":813,"type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"premium","limit_name":null,"primary":null,"secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":null},"plan_type":"team","rate_limit_reached_type":"workspace_member_credits_depleted"}}}
  """

private let claudeSnapshot = """
  {"five_hour":{"used_percentage":42.5,"resets_at":1790093632},"seven_day":{"used_percentage":13,"resets_at":1790435646}}
  """

@Test("Codex: оба окна из последней записи")
func codexParsesBothWindows() throws {
  let usage = try #require(AgentUsageParser.codex(tail: "{\"type\":\"other\"}\n" + codexLine))

  #expect(usage.agent == .codex)
  #expect(usage.windows.count == 2)
  #expect(usage.windows[0].duration == 5 * 60 * 60)
  #expect(usage.windows[0].usedPercent == 96)
  #expect(usage.windows[0].resetsAt == Date(timeIntervalSince1970: 1_790_093_632))
  #expect(usage.windows[1].duration == 7 * 24 * 60 * 60)
  #expect(usage.windows[1].usedPercent == 39)
}

@Test("Codex: момент снимка берётся из строки, с долями секунды")
func codexTakesTimestampFromLine() throws {
  let usage = try #require(AgentUsageParser.codex(tail: codexLine))
  let expected = try Date(
    "2026-09-22T13:56:02.121Z",
    strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
  )

  #expect(usage.measuredAt == expected)
}

@Test("Codex: запись без окон не перекрывает предыдущую с данными")
func codexSkipsEmptyRecord() throws {
  let usage = try #require(AgentUsageParser.codex(tail: codexLine + "\n" + codexEmptyLine))

  #expect(usage.windows.count == 2)
}

@Test("Codex: только пустые записи — снимка нет")
func codexWithoutWindowsGivesNothing() {
  #expect(AgentUsageParser.codex(tail: codexEmptyLine) == nil)
}

@Test("Codex: обрезанная первая строка и мусор не мешают")
func codexToleratesBrokenLines() throws {
  let tail = "ts\":\"broken\", \"rate_limits\": {\n" + codexLine + "\nнечто\n"

  #expect(AgentUsageParser.codex(tail: tail) != nil)
}

@Test("Codex: одно окно null — второе остаётся")
func codexKeepsRemainingWindow() throws {
  let line = codexLine.replacingOccurrences(
    of: #""primary":{"used_percent":96.0,"window_minutes":300,"resets_at":1790093632}"#,
    with: #""primary":null"#
  )
  let usage = try #require(AgentUsageParser.codex(tail: line))

  #expect(usage.windows.count == 1)
  #expect(usage.windows[0].usedPercent == 39)
}

@Test("Claude: оба окна из снимка statusLine")
func claudeParsesBothWindows() throws {
  let measuredAt = Date(timeIntervalSince1970: 1_790_000_000)
  let usage = try #require(
    AgentUsageParser.claude(snapshot: Data(claudeSnapshot.utf8), measuredAt: measuredAt)
  )

  #expect(usage.agent == .claudeCode)
  #expect(usage.measuredAt == measuredAt)
  let percents: [Double] = usage.windows.map(\.usedPercent)
  let durations: [TimeInterval] = usage.windows.map(\.duration)
  #expect(percents == [42.5, 13])
  #expect(durations == [18_000, 604_800])
}

@Test("Claude: неизвестные ключи игнорируются, мусор даёт nil")
func claudeToleratesUnknownAndGarbage() {
  let extended = Data(
    #"{"spend_limit":{"used_percentage":1,"resets_at":1},"seven_day":{"used_percentage":5,"resets_at":1790435646}}"#
      .utf8)
  let now = Date()

  #expect(AgentUsageParser.claude(snapshot: extended, measuredAt: now)?.windows.count == 1)
  #expect(AgentUsageParser.claude(snapshot: Data("не json".utf8), measuredAt: now) == nil)
  #expect(AgentUsageParser.claude(snapshot: Data("{}".utf8), measuredAt: now) == nil)
  #expect(
    AgentUsageParser.claude(
      snapshot: Data(#"{"five_hour":{"used_percentage":true,"resets_at":1}}"#.utf8),
      measuredAt: now
    ) == nil
  )
}

@Test("Окно после сброса пустое, до сброса — как в снимке")
func windowIsEmptyAfterReset() {
  let resetsAt = Date(timeIntervalSince1970: 1_790_093_632)
  let window = UsageWindow(duration: 300 * 60, usedPercent: 96, resetsAt: resetsAt)

  #expect(window.usedPercent(at: resetsAt.addingTimeInterval(-1)) == 96)
  #expect(window.usedPercent(at: resetsAt) == 0)
}

@Test("Доля за пределами 0…100 обрезается")
func windowClampsPercent() {
  let date = Date()

  #expect(UsageWindow(duration: 1, usedPercent: 140, resetsAt: date).usedPercent == 100)
  #expect(UsageWindow(duration: 1, usedPercent: -3, resetsAt: date).usedPercent == 0)
}

// Ответ `get_usage` Claude Code 2.1.267, 2026-09-23, сокращён до нужных ключей.
private let usageResponse = """
  {"type":"control_response","response":{"subtype":"success","request_id":"flowbar-usage","response":{"subscription_type":"pro","rate_limits_available":true,"rate_limits":{"five_hour":{"utilization":68,"resets_at":"2026-09-23T12:10:00.094959+00:00","limit_dollars":null},"seven_day":{"utilization":46,"resets_at":"2026-09-25T16:00:00.094984+00:00"},"seven_day_opus":null,"nimbus_quill":{"utilization":0,"resets_at":null}}}}}
  """

@Test("get_usage: оба окна, сброс с микросекундами")
func usageResponseParsesWindows() throws {
  let now = Date(timeIntervalSince1970: 1_790_160_000)
  let usage = try #require(
    AgentUsageParser.claudeUsageResponse(line: usageResponse, measuredAt: now))
  let expectedReset = try Date("2026-09-23T12:10:00Z", strategy: .iso8601)

  #expect(usage.agent == .claudeCode)
  #expect(usage.measuredAt == now)
  #expect(usage.windows.map(\.usedPercent) == [68, 46])
  #expect(abs(usage.windows[0].resetsAt.timeIntervalSince(expectedReset)) < 1)
}

@Test("get_usage: чужой ответ, ошибка и лимиты null не дают снимка")
func usageResponseRejectsOthers() {
  let now = Date()
  let other = usageResponse.replacingOccurrences(of: "flowbar-usage", with: "u2")
  let failure =
    #"{"type":"control_response","response":{"subtype":"error","request_id":"flowbar-usage","error":"get_usage is not supported"}}"#
  let noLimits =
    #"{"type":"control_response","response":{"subtype":"success","request_id":"flowbar-usage","response":{"rate_limits_available":false,"rate_limits":null}}}"#

  #expect(AgentUsageParser.claudeUsageResponse(line: other, measuredAt: now) == nil)
  #expect(AgentUsageParser.claudeUsageResponse(line: failure, measuredAt: now) == nil)
  #expect(AgentUsageParser.claudeUsageResponse(line: noLimits, measuredAt: now) == nil)
  #expect(AgentUsageParser.isClaudeUsageResponse(line: failure))
  #expect(!AgentUsageParser.isClaudeUsageResponse(line: other))
  #expect(!AgentUsageParser.isClaudeUsageResponse(line: #"{"type":"system","subtype":"init"}"#))
}

@Test("get_usage: строка запроса — одна строка валидного JSON")
func usageRequestIsSingleLine() throws {
  let request = AgentUsageParser.claudeUsageRequest

  #expect(!request.contains("\n"))
  let object = try #require(
    try JSONSerialization.jsonObject(with: Data(request.utf8)) as? [String: Any]
  )
  #expect(object["request_id"] as? String == AgentUsageParser.claudeUsageRequestID)
}

@Test("get_usage: rate_limits_available false — лимитов плана нет")
func usageResponseUnavailable() {
  let unavailable =
    #"{"type":"control_response","response":{"subtype":"success","request_id":"flowbar-usage","response":{"subscription_type":null,"rate_limits_available":false,"rate_limits":{}}}}"#

  #expect(AgentUsageParser.isClaudeUsageUnavailable(line: unavailable))
  #expect(!AgentUsageParser.isClaudeUsageUnavailable(line: usageResponse))
  #expect(AgentUsageParser.claudeUsageResponse(line: unavailable, measuredAt: Date()) == nil)
}

@Test("Остаток — дополнение до 100, после сброса окно снова полное")
func windowRemaining() {
  let resetsAt = Date(timeIntervalSince1970: 1_790_093_632)
  let window = UsageWindow(duration: 300 * 60, usedPercent: 68, resetsAt: resetsAt)

  #expect(window.remainingPercent(at: resetsAt.addingTimeInterval(-1)) == 32)
  #expect(window.remainingPercent(at: resetsAt) == 100)
}
