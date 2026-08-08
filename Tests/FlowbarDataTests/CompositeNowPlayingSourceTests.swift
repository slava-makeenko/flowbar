import FlowbarData
import FlowbarDomain
import FlowbarTestSupport
import Testing

private let track = Track(title: "Ветер", artist: "Кто-то", source: "Music")

private func makeComposite(
  sources: [any NowPlayingReading],
  controller: FakePlaybackController = FakePlaybackController()
) -> CompositeNowPlayingSource {
  CompositeNowPlayingSource(
    metadataSources: sources,
    seekingSources: [],
    controller: controller
  )
}

@Test("Берётся первый источник, которому есть что сказать")
func picksFirstAnsweringSource() async {
  let composite = makeComposite(sources: [
    FakeNowPlayingSource(answer: .silence),
    FakeNowPlayingSource(answer: .track(track)),
    FakeNowPlayingSource(answer: .application(name: "Safari")),
  ])

  #expect(await composite.current() == .track(track))
}

@Test("Имя приложения используется, только когда трека не знает никто")
func fallsBackToApplication() async {
  let composite = makeComposite(sources: [
    FakeNowPlayingSource(answer: .silence),
    FakeNowPlayingSource(answer: .application(name: "Safari")),
  ])

  #expect(await composite.current() == .application(name: "Safari"))
}

@Test("Когда молчат все, композит не выдумывает трек")
func returnsSilenceWhenNobodyKnows() async {
  let composite = makeComposite(sources: [
    FakeNowPlayingSource(answer: .silence),
    FakeNowPlayingSource(answer: .silence),
  ])

  #expect(await composite.current() == .silence)
}

@Test("Управление работает и при полном отсутствии метаданных")
func controlWorksWithoutMetadata() async {
  let controller = FakePlaybackController()
  let composite = makeComposite(
    sources: [FakeNowPlayingSource(answer: .silence)],
    controller: controller
  )

  await composite.toggle()
  await composite.next()
  await composite.previous()

  #expect(await composite.current() == .silence)
  #expect(await controller.commands == ["toggle", "next", "previous"])
}
