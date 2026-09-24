import FlowbarDomain
import Foundation
import Testing

private let hour: TimeInterval = 3600
private let reset = Date(timeIntervalSince1970: 1_790_100_000)

/// Пятичасовое окно, начавшееся за пять часов до `reset`.
private func session(_ percent: Double) -> UsageWindow {
  UsageWindow(duration: 5 * hour, usedPercent: percent, resetsAt: reset)
}

/// Момент через `hours` часов после начала пятичасового окна.
private func into(_ hours: Double) -> Date {
  reset.addingTimeInterval(-5 * hour + hours * hour)
}

@Test("Половина за два часа — кончится через четыре часа после начала")
func forecastRunsOut() {
  #expect(session(50).forecast(measuredAt: into(2)) == .runsOut(at: into(4)))
}

@Test("Четверть за два часа — хватит до сброса")
func forecastLastsUntilReset() {
  #expect(session(25).forecast(measuredAt: into(2)) == .lastsUntilReset)
}

@Test("Ровно к сбросу — хватает: кончается не раньше сброса")
func forecastExactlyAtReset() {
  #expect(session(40).forecast(measuredAt: into(2)) == .lastsUntilReset)
}

@Test("Прогноз молчит: мало прошло, пусто, исчерпано, сброшено")
func forecastNeedsData() {
  #expect(session(10).forecast(measuredAt: into(0.2)) == nil)
  #expect(session(10).forecast(measuredAt: into(0.25)) != nil)
  #expect(session(0).forecast(measuredAt: into(2)) == nil)
  #expect(session(100).forecast(measuredAt: into(2)) == nil)
  #expect(session(50).forecast(measuredAt: reset) == nil)
}

private func usage(_ agent: Agent, _ percent: Double, measured: Date = into(2)) -> AgentUsage {
  AgentUsage(agent: agent, windows: [session(percent)], measuredAt: measured)
}

@Test("Совет: у Claude окно кончается, у Codex свободно")
func adviceSuggestsOtherAgent() throws {
  let advice = try #require(
    LimitAdvice.find(in: [usage(.claudeCode, 60), usage(.codex, 20)], at: into(2))
  )

  #expect(advice.from == .claudeCode)
  #expect(advice.to == .codex)
  #expect(advice.window.usedPercent == 20)
}

@Test("Совет по порогу 90 %, даже когда прогноз молчит")
func adviceByThreshold() {
  let nearly = usage(.codex, 95, measured: into(0.1))

  #expect(LimitAdvice.find(in: [nearly, usage(.claudeCode, 10)], at: into(0.1))?.to == .claudeCode)
}

@Test("Совета нет: у второго занято много или тоже кончается, или всё в порядке")
func adviceAbsent() {
  #expect(LimitAdvice.find(in: [usage(.claudeCode, 60), usage(.codex, 85)], at: into(2)) == nil)
  #expect(LimitAdvice.find(in: [usage(.claudeCode, 60), usage(.codex, 45)], at: into(2)) == nil)
  #expect(LimitAdvice.find(in: [usage(.claudeCode, 20), usage(.codex, 20)], at: into(2)) == nil)
  #expect(LimitAdvice.find(in: [usage(.claudeCode, 60)], at: into(2)) == nil)
}

@Test("После сброса окно не кончается и совета нет")
func adviceAfterReset() {
  #expect(LimitAdvice.find(in: [usage(.claudeCode, 95), usage(.codex, 10)], at: reset) == nil)
}

@Test("Снимок устарел, если агент работал после него дольше допуска")
func usageOutdatedAfterActivity() {
  let measured = into(2)
  let base = AgentUsage(agent: .claudeCode, windows: [session(49)], measuredAt: measured)

  #expect(!base.isOutdated)
  #expect(!base.withLastActivity(measured.addingTimeInterval(119)).isOutdated)
  #expect(base.withLastActivity(measured.addingTimeInterval(121)).isOutdated)
  #expect(!base.withLastActivity(measured.addingTimeInterval(-600)).isOutdated)
}

@Test("Устаревший снимок не участвует в совете")
func outdatedUsageGivesNoAdvice() {
  let stale = usage(.codex, 20).withLastActivity(into(3))

  #expect(LimitAdvice.find(in: [usage(.claudeCode, 60), stale], at: into(3)) == nil)
}
