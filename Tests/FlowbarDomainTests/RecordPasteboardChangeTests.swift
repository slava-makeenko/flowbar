import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

private let moment = Date(timeIntervalSince1970: 1_700_000_000)
private let notes = SourceApp(name: "Notes", bundleIdentifier: "com.apple.Notes")

private func makeUseCase(
  pasteboard: FakePasteboard,
  clips: FakeClipStore,
  blobs: FakeBlobStore = FakeBlobStore(),
  blocked: Set<String> = []
) -> RecordPasteboardChange {
  RecordPasteboardChange(
    pasteboard: pasteboard,
    clips: clips,
    blobs: blobs,
    clock: FixedClock(now: moment),
    blockedBundleIdentifiers: blocked
  )
}

@Test("Обычная копия попадает в историю")
func savesPlainCopy() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)
  await pasteboard.copy(PasteboardItem(text: "черновик письма", sourceApp: notes))

  let saved = await useCase()

  #expect(saved?.preview == "черновик письма")
  #expect(saved?.kind == .text)
  #expect(saved?.sourceApp == "Notes")
  #expect(saved?.capturedAt == moment)
  #expect(await clips.saved.count == 1)
}

@Test("Конфиденциальная копия в историю не попадает")
func skipsConcealedCopy() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)
  await pasteboard.copy(
    PasteboardItem(text: "hunter2", isConcealed: true, sourceApp: notes)
  )

  let saved = await useCase()

  #expect(saved == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Временная копия в историю не попадает")
func skipsTransientCopy() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)
  await pasteboard.copy(
    PasteboardItem(text: "временное", isTransient: true, sourceApp: notes)
  )

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Копия из приложения в чёрном списке в историю не попадает")
func skipsBlockedApp() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips, blocked: ["com.apple.Notes"])
  await pasteboard.copy(PasteboardItem(text: "секрет", sourceApp: notes))

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Собственная запись приложения не возвращается в историю")
func skipsOwnWrite() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)

  await pasteboard.write(text: "скопировано из истории")
  await useCase.noteOwnWrite()

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Без пометки собственной записи та же копия сохранилась бы")
func ownWriteGuardIsWhatStopsIt() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)

  await pasteboard.write(text: "скопировано из истории")

  #expect(await useCase() != nil)
}

@Test("Повторный опрос без изменения пастборда ничего не добавляет")
func ignoresUnchangedPasteboard() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)
  await pasteboard.copy(PasteboardItem(text: "один раз", sourceApp: notes))

  await useCase()
  await useCase()

  #expect(await clips.saved.count == 1)
}

@Test("Растр уходит в хранилище файлов, а в записи остаётся путь")
func storesImageAsBlob() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let blobs = FakeBlobStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips, blobs: blobs)
  await pasteboard.copy(PasteboardItem(imageData: Data([0x89, 0x50]), sourceApp: notes))

  let saved = await useCase()

  #expect(saved?.kind == .image)
  if case .imageFile(let url) = saved?.payload {
    #expect(await blobs.stored[saved?.id ?? UUID()] == url)
  } else {
    Issue.record("ожидался payload .imageFile")
  }
}

@Test("Если растр не сохранился, запись не заводится")
func skipsClipWhenBlobStoreFails() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(
    pasteboard: pasteboard,
    clips: clips,
    blobs: FakeBlobStore(succeeds: false)
  )
  await pasteboard.copy(PasteboardItem(imageData: Data([0x89]), sourceApp: notes))

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Превью схлопывается в одну строку")
func previewIsSingleLine() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)
  await pasteboard.copy(PasteboardItem(text: "первая\nвторая\nтретья", sourceApp: notes))

  let saved = await useCase()

  #expect(saved?.preview == "первая вторая третья")
}
