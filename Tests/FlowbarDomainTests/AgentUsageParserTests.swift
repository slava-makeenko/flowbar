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
