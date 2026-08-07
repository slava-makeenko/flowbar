import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

private let now = Date(timeIntervalSince1970: 1_700_000_000)
private let week: TimeInterval = 7 * 24 * 60 * 60

private func clip(
  ageInSeconds age: TimeInterval,
  payload: ClipPayload = .string("что-то")
) -> ClipItem {
  ClipItem(
    id: UUID(),
    kind: .text,
    preview: "что-то",
    payload: payload,
    sourceApp: "Notes",
    capturedAt: now.addingTimeInterval(-age)
  )
}

@Test("Запись ровно семидневной давности остаётся")
func keepsClipExactlyAtBoundary() async {
  let store = FakeClipStore(saved: [clip(ageInSeconds: week)])
  let prune = PruneExpiredClips(clips: store, blobs: FakeBlobStore(), clock: FixedClock(now: now))

  let removed = await prune()

  #expect(removed == 0)
  #expect(await store.saved.count == 1)
}

@Test("Запись на секунду старше семи дней удаляется")
func removesClipPastBoundary() async {
  let store = FakeClipStore(saved: [clip(ageInSeconds: week + 1)])
  let prune = PruneExpiredClips(clips: store, blobs: FakeBlobStore(), clock: FixedClock(now: now))

  let removed = await prune()

  #expect(removed == 1)
  #expect(await store.saved.isEmpty)
}

@Test("Свежие записи не трогаются")
func keepsFreshClips() async {
  let store = FakeClipStore(saved: [clip(ageInSeconds: 60), clip(ageInSeconds: week + 1)])
  let prune = PruneExpiredClips(clips: store, blobs: FakeBlobStore(), clock: FixedClock(now: now))

  await prune()

  #expect(await store.saved.count == 1)
}

@Test("Растр удаляется вместе с записью")
func removesBlobWithClip() async {
  let url = URL(fileURLWithPath: "/blobs/old.png")
  let store = FakeClipStore(saved: [clip(ageInSeconds: week + 1, payload: .imageFile(url))])
  let blobs = FakeBlobStore()
  let prune = PruneExpiredClips(clips: store, blobs: blobs, clock: FixedClock(now: now))

  await prune()

  #expect(await blobs.removed == [url])
  #expect(await store.saved.isEmpty)
}

@Test("Пустая история не вызывает удаления")
func doesNothingOnEmptyHistory() async {
  let blobs = FakeBlobStore()
  let prune = PruneExpiredClips(clips: FakeClipStore(), blobs: blobs, clock: FixedClock(now: now))

  #expect(await prune() == 0)
  #expect(await blobs.removed.isEmpty)
}
