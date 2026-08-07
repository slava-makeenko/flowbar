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
  blocked: Set<String> = [],
  clock: any Clock = FixedClock(now: moment)
) -> RecordPasteboardChange {
  RecordPasteboardChange(
    pasteboard: pasteboard,
    clips: clips,
    blobs: blobs,
    clock: clock,
    blockedBundleIdentifiers: blocked
  )
}

/// Юзкейс, уже переживший первый опрос.
///
/// Первое замеченное изменение всегда пропускается — это содержимое пастборда до запуска.
/// Тестам, которые проверяют не это, стартовый опрос нужно погасить.
private func makeStartedUseCase(
  pasteboard: FakePasteboard,
  clips: FakeClipStore,
  blobs: FakeBlobStore = FakeBlobStore(),
  blocked: Set<String> = [],
  clock: any Clock = FixedClock(now: moment)
) async -> RecordPasteboardChange {
  let useCase = makeUseCase(
    pasteboard: pasteboard, clips: clips, blobs: blobs, blocked: blocked, clock: clock)
  await useCase()
  return useCase
}

@Test("Обычная копия попадает в историю")
func savesPlainCopy() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)
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
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)
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
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)
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
  let useCase = await makeStartedUseCase(
    pasteboard: pasteboard, clips: clips, blocked: ["com.apple.Notes"])
  await pasteboard.copy(PasteboardItem(text: "секрет", sourceApp: notes))

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Собственная запись приложения не возвращается в историю")
func skipsOwnWrite() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)

  await pasteboard.write(text: "скопировано из истории")
  await useCase.noteOwnWrite()

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Без пометки собственной записи та же копия сохранилась бы")
func ownWriteGuardIsWhatStopsIt() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)

  await pasteboard.write(text: "скопировано из истории")

  #expect(await useCase() != nil)
}

@Test("Повторный опрос без изменения пастборда ничего не добавляет")
func ignoresUnchangedPasteboard() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)
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
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips, blobs: blobs)
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
  let useCase = await makeStartedUseCase(
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
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)
  await pasteboard.copy(PasteboardItem(text: "первая\nвторая\nтретья", sourceApp: notes))

  let saved = await useCase()

  #expect(saved?.preview == "первая вторая третья")
}

// MARK: - Содержимое до запуска и повторные копии

@Test("Содержимое пастборда до запуска в историю не попадает")
func skipsContentFromBeforeLaunch() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  await pasteboard.copy(PasteboardItem(text: "лежало до запуска", sourceApp: notes))
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)

  #expect(await useCase() == nil)
  #expect(await clips.saved.isEmpty)
}

@Test("Копия, сделанная после запуска, сохраняется как обычно")
func savesContentAfterLaunch() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  await pasteboard.copy(PasteboardItem(text: "лежало до запуска", sourceApp: notes))
  let useCase = makeUseCase(pasteboard: pasteboard, clips: clips)
  await useCase()

  await pasteboard.copy(PasteboardItem(text: "скопировано после", sourceApp: notes))

  #expect(await useCase()?.preview == "скопировано после")
  #expect(await clips.saved.count == 1)
}

@Test("Повторная копия того же текста поднимается наверх со свежим временем")
func promotesRepeatedCopy() async {
  let later = moment.addingTimeInterval(3600)
  let clock = MutableClock(now: moment)
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips, clock: clock)

  await pasteboard.copy(PasteboardItem(text: "адрес офиса", sourceApp: notes))
  let first = await useCase()

  clock.now = later
  await pasteboard.copy(PasteboardItem(text: "адрес офиса", sourceApp: notes))
  let second = await useCase()

  #expect(await clips.saved.count == 1)
  #expect(second?.capturedAt == later)
  #expect(second?.id != first?.id)
}

@Test("Разный текст даёт разные записи")
func keepsDistinctCopies() async {
  let pasteboard = FakePasteboard()
  let clips = FakeClipStore()
  let useCase = await makeStartedUseCase(pasteboard: pasteboard, clips: clips)

  await pasteboard.copy(PasteboardItem(text: "первое", sourceApp: notes))
  await useCase()
  await pasteboard.copy(PasteboardItem(text: "второе", sourceApp: notes))
  await useCase()

  #expect(await clips.saved.count == 2)
}
