import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

private let start = Date(timeIntervalSince1970: 1_790_000_000)

@Test("Запись зажигает агента, тишина дольше окна гасит")
func writeLightsAndSilenceDims() {
  let clock = MutableClock(now: start)
  var activity = AgentActivity(holdWindow: 20)

  activity.recordWrite(by: .codex, at: clock.now)
  clock.now = start.addingTimeInterval(19.9)
  #expect(activity.working(at: clock.now) == [.codex])

  clock.now = start.addingTimeInterval(20)
  #expect(activity.working(at: clock.now).isEmpty)
}

@Test("Новая запись продлевает окно")
func newWriteExtendsWindow() {
  var activity = AgentActivity(holdWindow: 20)

  activity.recordWrite(by: .claudeCode, at: start)
  activity.recordWrite(by: .claudeCode, at: start.addingTimeInterval(15))

  #expect(activity.working(at: start.addingTimeInterval(30)) == [.claudeCode])
}

@Test("Опоздавшее событие не откатывает время последней записи назад")
func lateEventDoesNotRewind() {
  var activity = AgentActivity(holdWindow: 20)

  activity.recordWrite(by: .codex, at: start.addingTimeInterval(15))
  activity.recordWrite(by: .codex, at: start)

  #expect(activity.working(at: start.addingTimeInterval(30)) == [.codex])
}

@Test("Агенты независимы")
func agentsAreIndependent() {
  var activity = AgentActivity(holdWindow: 20)

  activity.recordWrite(by: .claudeCode, at: start)
  activity.recordWrite(by: .codex, at: start.addingTimeInterval(10))

  #expect(activity.working(at: start.addingTimeInterval(5)) == [.claudeCode, .codex])
  #expect(activity.working(at: start.addingTimeInterval(25)) == [.codex])
}

@Test("Следующая смена — ближайшее затухание в будущем")
func nextChangeIsNearestFade() {
  var activity = AgentActivity(holdWindow: 20)
  #expect(activity.nextChange(after: start) == nil)

  activity.recordWrite(by: .claudeCode, at: start)
  activity.recordWrite(by: .codex, at: start.addingTimeInterval(10))

  #expect(activity.nextChange(after: start.addingTimeInterval(5)) == start.addingTimeInterval(20))
  #expect(activity.nextChange(after: start.addingTimeInterval(20)) == start.addingTimeInterval(30))
  #expect(activity.nextChange(after: start.addingTimeInterval(30)) == nil)
}
