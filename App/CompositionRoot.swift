import FlowbarData
import FlowbarDomain
import FlowbarPresentation
import FlowbarUI
import Foundation
import SwiftUI

/// Единственное место, где встречаются конкретные типы: регламент §5, DIP.
///
/// Синглтонов в проекте нет — всё, что нужно модулям, собирается здесь и передаётся
/// через инициализаторы.
@MainActor
final class CompositionRoot {

  /// Как часто чистится история от записей старше срока жизни.
  private static let pruneInterval: Duration = .seconds(3600)

  private let clock: any Clock = SystemClock()
  private let shellState = ShellState()
  private let feedback = CopyFeedback()

  private var shell: NotchWindowController?
  private var watcher: PasteboardWatcher?
  private var backgroundWork: [Task<Void, Never>] = []

  /// Поднимает приложение.
  func start() {
    let clips = SQLiteClipStore(fileURL: Self.supportDirectory.appending(path: "clips.sqlite"))
    let blobs = FileSystemBlobStore(directory: Self.supportDirectory.appending(path: "clips"))
    let system = NSPasteboardAdapter()

    let recorder = RecordPasteboardChange(
      pasteboard: system,
      clips: clips,
      blobs: blobs,
      clock: clock,
      blockedBundleIdentifiers: RecordPasteboardChange.defaultBlockedBundleIdentifiers
    )
    // Все записи приложения идут через обёртку, поэтому скопированное из истории
    // не возвращается в историю — про это не нужно помнить в каждой вью-модели.
    let pasteboard = RecordingPasteboardWriter(pasteboard: system, recorder: recorder)

    let clipboard = ClipboardViewModel(
      store: clips,
      files: FileSystemFileReader(),
      pasteboard: pasteboard,
      feedback: feedback
    )
    let watcher = PasteboardWatcher(record: recorder)
    self.watcher = watcher

    // Сессию перевода отдаёт только модификатор SwiftUI, поэтому адаптер работает в паре
    // с невидимой вью. В оболочку она попадает стёртой до AnyView — слой UI про фреймворк
    // Translation не знает. ADR-0009.
    let translator = AppleTranslationAdapter()
    let translate = TranslateViewModel(
      translate: TranslateText(translator: translator, languageDetector: NLLanguageDetector()),
      languageDetector: NLLanguageDetector(),
      pasteboard: pasteboard,
      feedback: feedback,
      targetLanguage: Language(code: "en")
    )

    let shell = NotchWindowController(
      state: shellState,
      clipboard: clipboard,
      translate: translate,
      snippets: makeSnippetsViewModel(pasteboard: pasteboard),
      feedback: feedback,
      backgroundHosts: AnyView(TranslationSessionHost(adapter: translator))
    )
    shell.start()
    self.shell = shell

    backgroundWork = [
      Task { await watcher.start() },
      Task { await clipboard.observe(watcher.recordedClips) },
      Task { await Self.prunePeriodically(clips: clips, blobs: blobs, clock: clock) },
    ]
  }

  /// Останавливает фоновую работу.
  func stop() {
    backgroundWork.forEach { $0.cancel() }
    backgroundWork = []
  }

  private func makeSnippetsViewModel(
    pasteboard: any PasteboardWriting
  ) -> SnippetsViewModel {
    let store = JSONSnippetStore(directory: Self.supportDirectory)
    return SnippetsViewModel(
      store: store,
      addSnippet: AddSnippet(store: store),
      pasteboard: pasteboard,
      feedback: feedback
    )
  }

  /// Чистит историю на старте и дальше раз в час.
  private static func prunePeriodically(
    clips: any ClipStoring,
    blobs: any BlobStoring,
    clock: any Clock
  ) async {
    let prune = PruneExpiredClips(clips: clips, blobs: blobs, clock: clock)
    while !Task.isCancelled {
      await prune()
      try? await Task.sleep(for: pruneInterval)
    }
  }

  /// Каталог приложения в Application Support.
  ///
  /// В песочнице путь ведёт внутрь контейнера, снаружи — в домашнюю библиотеку.
  private static var supportDirectory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    return (base.first ?? URL(filePath: NSTemporaryDirectory())).appending(path: "Flowbar")
  }
}
