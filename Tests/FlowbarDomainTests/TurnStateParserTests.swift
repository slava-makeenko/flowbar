import FlowbarDomain
import Foundation
import Testing

// Строки сокращены из транскриптов Claude Code 2.1.267 и codex-cli 0.153.4, 2026-09-23.

private let claudeToolUse = """
  {"type":"assistant","timestamp":"2026-09-23T10:15:30.000Z","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use"}]}}
  """
private let claudeToolResult = """
  {"type":"user","timestamp":"2026-09-23T10:15:31.000Z","message":{"role":"user","content":[{"type":"tool_result"}]}}
  """
private let claudeEndTurn = """
  {"type":"assistant","timestamp":"2026-09-23T10:15:34.000Z","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text"}]}}
  """
private let claudeTurnDuration = """
  {"type":"system","subtype":"turn_duration","timestamp":"2026-09-23T10:15:35.544Z"}
  """
private let claudeMetadata = """
  {"type":"last-prompt","lastPrompt":"…"}
  {"type":"mode","mode":"auto"}
  {"type":"attachment","timestamp":"2026-09-23T10:15:36.000Z"}
  {"type":"system","subtype":"informational","timestamp":"2026-09-23T10:15:37.000Z"}
  """

@Test("Claude: вызов инструмента и его результат — ход идёт")
func claudeToolCallIsWorking() {
  #expect(TurnStateParser.claude(tail: claudeToolUse) == .working)
  #expect(TurnStateParser.claude(tail: claudeToolUse + "\n" + claudeToolResult) == .working)
}

@Test("Claude: end_turn и turn_duration — ход кончился")
func claudeEndOfTurnIsWaiting() {
  #expect(TurnStateParser.claude(tail: claudeToolResult + "\n" + claudeEndTurn) == .waiting)
  #expect(TurnStateParser.claude(tail: claudeEndTurn + "\n" + claudeTurnDuration) == .waiting)
}

@Test("Claude: служебные строки после конца хода не меняют состояние")
func claudeSkipsMetadata() {
  let tail = [claudeEndTurn, claudeTurnDuration, claudeMetadata].joined(separator: "\n")

  #expect(TurnStateParser.claude(tail: tail) == .waiting)
}

@Test("Claude: хвост без маркеров и мусор дают nil")
func claudeWithoutMarkers() {
  #expect(TurnStateParser.claude(tail: claudeMetadata) == nil)
  #expect(TurnStateParser.claude(tail: "\"type\":\"assistant\" обрывок\nне json") == nil)
}

private let codexStarted = """
  {"timestamp":"2026-09-23T05:58:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
  """
private let codexItem = """
  {"timestamp":"2026-09-23T05:58:10.000Z","type":"response_item","payload":{"type":"function_call"}}
  """
private let codexComplete = """
  {"timestamp":"2026-09-23T05:58:16.418Z","type":"event_msg","payload":{"type":"task_complete"}}
  """
private let codexSettings = """
  {"timestamp":"2026-09-23T08:19:12.959Z","type":"event_msg","payload":{"type":"thread_settings_applied"}}
  """

@Test("Codex: task_started — ход идёт, task_complete и turn_aborted — кончился")
func codexTurnMarkers() {
  #expect(TurnStateParser.codex(tail: codexStarted + "\n" + codexItem) == .working)
  #expect(TurnStateParser.codex(tail: codexStarted + "\n" + codexComplete) == .waiting)
  let aborted = codexComplete.replacingOccurrences(of: "task_complete", with: "turn_aborted")
  #expect(TurnStateParser.codex(tail: codexStarted + "\n" + aborted) == .waiting)
}

@Test("Codex: thread_settings_applied после конца хода не меняет состояние")
func codexSkipsSettings() {
  #expect(TurnStateParser.codex(tail: codexComplete + "\n" + codexSettings) == .waiting)
  #expect(TurnStateParser.codex(tail: codexSettings) == nil)
}

@Test("Codex: субагент узнаётся по session_meta")
func codexSubagentDetection() {
  let guardian = #"{"type":"session_meta","payload":{"source":{"subagent":{"other":"guardian"}}}}"#
  let spawned =
    #"{"type":"session_meta","payload":{"source":{"subagent":{"thread_spawn":{"depth":1}}}}}"#
  let main = #"{"type":"session_meta","payload":{"source":"cli"}}"#

  #expect(TurnStateParser.isCodexSubagent(sessionMeta: guardian))
  #expect(TurnStateParser.isCodexSubagent(sessionMeta: spawned))
  #expect(!TurnStateParser.isCodexSubagent(sessionMeta: main))
  #expect(!TurnStateParser.isCodexSubagent(sessionMeta: "мусор"))
}
