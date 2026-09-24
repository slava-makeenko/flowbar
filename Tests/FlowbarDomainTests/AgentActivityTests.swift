import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

private let start = Date(timeIntervalSince1970: 1_790_000_000)

private func change(
  _ agent: Agent = .codex,
  session: String = "a",
  turn: TurnState? = .working,
  subagent: Bool = false
) -> TranscriptChange {
  TranscriptChange(agent: agent, session: session, isSubagent: subagent, turn: turn)
}

private func at(_ seconds: TimeInterval) -> Date {
  start.addingTimeInterval(seconds)
}

@Test("Запись посреди хода зажигает, тишина дольше окна гасит")
func workingFadesAfterSilence() {
  let clock = MutableClock(now: at(1))
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(), at: clock.now)
  clock.now = at(20.9)
  #expect(activity.working(at: clock.now) == [.codex])

  clock.now = at(21)
  #expect(activity.working(at: clock.now).isEmpty)
}

@Test("Конец хода гасит сразу, не дожидаясь окна")
func turnEndDimsImmediately() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(turn: .working), at: at(1))
  activity.record(change(turn: .waiting), at: at(5))

  #expect(activity.working(at: at(5)).isEmpty)
  #expect(activity.nextChange(after: at(5)) == nil)
}

@Test("Служебная запись после конца хода не зажигает")
func metadataAfterTurnEndIsNotWork() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(turn: .waiting), at: at(5))
  activity.record(change(turn: .waiting), at: at(7))

  #expect(activity.working(at: at(8)).isEmpty)
}

@Test("Новый ход зажигает снова")
func newTurnLightsAgain() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(turn: .waiting), at: at(5))
  activity.record(change(turn: .working), at: at(12))

  #expect(activity.working(at: at(13)) == [.codex])
}

@Test("Запись без маркера хода считается работой")
func unknownTurnCountsAsWork() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(turn: nil), at: at(1))

  #expect(activity.working(at: at(10)) == [.codex])
}

@Test("Конец хода субагента не гасит: его запись — работа")
func subagentTurnEndIsWork() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(turn: .waiting, subagent: true), at: at(1))

  #expect(activity.working(at: at(2)) == [.codex])
  #expect(activity.working(at: at(22)).isEmpty)
}

@Test("Одна сессия закончила ход, другая работает — агент работает")
func anyWorkingSessionCounts() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(session: "a", turn: .working), at: at(1))
  activity.record(change(session: "b", turn: .waiting), at: at(2))

  #expect(activity.working(at: at(3)) == [.codex])
}

@Test("Агенты независимы")
func agentsAreIndependent() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(.claudeCode, session: "c", turn: .working), at: at(1))
  activity.record(change(.codex, session: "x", turn: .working), at: at(10))

  #expect(activity.working(at: at(5)) == [.claudeCode, .codex])
  #expect(activity.working(at: at(25)) == [.codex])
}

@Test("Опоздавшее событие не откатывает время последней записи")
func lateEventDoesNotRewind() {
  var activity = AgentActivity(holdWindow: 20)

  activity.record(change(turn: nil), at: at(15))
  activity.record(change(turn: nil), at: at(1))

  #expect(activity.working(at: at(30)) == [.codex])
}

@Test("Следующая смена — ближайшее затухание")
func nextChangeIsNearestFade() {
  var activity = AgentActivity(holdWindow: 20)
  #expect(activity.nextChange(after: start) == nil)

  activity.record(change(session: "a", turn: .working), at: at(1))
  activity.record(change(session: "b", turn: .working), at: at(10))

  #expect(activity.nextChange(after: at(5)) == at(21))
  #expect(activity.nextChange(after: at(21)) == at(30))
  #expect(activity.nextChange(after: at(30)) == nil)
}
