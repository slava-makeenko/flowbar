import FlowbarTestSupport
import Foundation
import Testing

@Test("FixedClock отдаёт заданный момент без изменений")
func fixedClockReturnsGivenInstant() {
  let instant = Date(timeIntervalSince1970: 1_000_000)

  let clock = FixedClock(now: instant)

  #expect(clock.now == instant)
}
