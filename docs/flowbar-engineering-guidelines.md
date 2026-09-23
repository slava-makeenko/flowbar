# Flowbar — инженерный регламент

Постоянные правила разработки. Применяются ко всему коду проекта, а не только к текущей спецификации. Спецификация реализации — `flowbar-macos-spec.md` — описывает **что** делать; этот документ — **как**.

---

## 1. Приоритет правил при конфликте

Принципы противоречат друг другу чаще, чем принято признавать. Порядок разрешения:

1. **Правило зависимостей чистой архитектуры не нарушается никогда.** Это единственное, ради чего архитектура и берётся. Нарушение обесценивает всё остальное.
2. **KISS выше церемонии.** Слой обязателен, отдельный тип на каждую операцию — нет. Критерий появления типа — §4.
3. **DRY применяется к знанию, а не к форме.** Две одинаково выглядящие структуры, которые будут меняться по разным причинам, не объединяются. Подробнее — §6.
4. **Стиль кода не обсуждается в ревью.** Его чинит форматтер на pre-commit. Ревью — про границы слоёв и контракты.

---

## 2. Слои и правило зависимостей

```
        ┌──────────────────────────────────────────┐
        │  App — композиционный корень             │  знает всех
        └──────────────────────────────────────────┘
             │              │                │
             ▼              ▼                ▼
        ┌─────────┐   ┌────────────┐   ┌──────────────┐
        │   UI    │──▶│Presentation│──▶│    Domain    │
        │ SwiftUI │   │ ViewModels │   │ Entities     │
        │ AppKit  │   │            │   │ UseCases     │
        └─────────┘   └────────────┘   │ Ports (protocol)
                                       └──────────────┘
                                              ▲
                                       ┌──────────────┐
                                       │     Data     │  реализует порты
                                       │ AppKit, CoreAudio,
                                       │ Translation, SQLite
                                       └──────────────┘
```

**Стрелки только внутрь.** `Domain` не импортирует ничего, кроме `Foundation`. Ни `AppKit`, ни `SwiftUI`, ни `Translation`, ни GRDB.

| Слой | Импортирует | Не знает про |
|---|---|---|
| `Domain` | `Foundation` | всё остальное |
| `Data` | `Domain` + системные фреймворки | UI, Presentation |
| `Presentation` | `Domain` | UI, Data, AppKit |
| `UI` | `Presentation`, `DesignSystem` | Data, системные API модулей |
| `App` | все | — |

### 2.1 Границы обеспечивает компилятор, а не дисциплина

Слои — **отдельные таргеты SPM**. Тогда запрещённый импорт не проходит сборку, и правило не нужно проверять на ревью.

```swift
// Package.swift
targets: [
  .target(name: "FlowbarDomain"),                                        // без зависимостей
  .target(name: "FlowbarData",         dependencies: ["FlowbarDomain"]),
  .target(name: "FlowbarPresentation", dependencies: ["FlowbarDomain"]),
  .target(name: "FlowbarDesignSystem"),
  .target(name: "FlowbarUI",           dependencies: ["FlowbarPresentation", "FlowbarDesignSystem"]),
  .target(name: "FlowbarTestSupport",  dependencies: ["FlowbarDomain"]),  // фейки портов
  .testTarget(name: "FlowbarDomainTests",
              dependencies: ["FlowbarDomain", "FlowbarTestSupport"]),
]
```

Приложение-таргет в Xcode зависит от всех и содержит только композиционный корень.

Линтерное правило «запретить `import AppKit` в Domain» — костыль вместо этого. Не заводить.

> **Поправка от 2026-08-06 — [ADR-0007](adr/0007-layer-boundary-check.md).** Замер на
> собранном каркасе показал, что компилятор закрывает только половину правила. Зависимости
> таргетов SPM ограничивают импорт **других таргетов пакета**: `import FlowbarData` в
> `Domain` сборку роняет. Системные фреймворки под это не подпадают: `import AppKit` в
> `Domain` и `import SwiftUI` в `Presentation` собираются без единого замечания — а правило
> заведено ровно ради них. Поэтому проверка всё же добавлена: `Scripts/check-layers.sh`,
> список разрешённого, вызывается из pre-commit и CI. Абзац выше сохранён как есть, чтобы
> было видно, какая посылка не подтвердилась.

---

## 3. Порты проекта

Порт объявляется в `Domain`, реализуется в `Data`. Один порт — одна причина существования.

| Порт | Назначение | Адаптеры |
|---|---|---|
| `PasteboardReading` | опрос пастборда, `changeCount` | `NSPasteboardAdapter` |
| `PasteboardWriting` | запись в пастборд | `NSPasteboardAdapter` |
| `ClipStoring` | история копий, чистка | `SQLiteClipStore` |
| `BlobStoring` | файлы изображений из истории | `FileSystemBlobStore` |
| `ScreenshotSourcing` | поток последних скриншотов | `SpotlightScreenshotSource` |
| `ThumbnailRendering` | превью | `QuickLookThumbnailRenderer` |
| `FileTrashing` | удаление в Корзину | `WorkspaceTrashAdapter` |
| `TextTranslating` | перевод | `AppleTranslationAdapter`, `UnavailableTranslationAdapter` |
| `LanguageDetecting` | определение языка | `NLLanguageDetector` |
| ~~`NowPlayingReading`~~ | метаданные трека | удалён, ADR-0011 |
| ~~`PlaybackControlling`~~ | play/pause/next/prev | удалён, ADR-0011 |
| ~~`PlaybackSeeking`~~ | позиция в треке | удалён, ADR-0011 |
| `SystemVolumeControlling` | системная громкость | `CoreAudioVolumeAdapter` |
| `SnippetStoring` | быстрые вставки | `JSONSnippetStore` |
| `AgentFolderAccessing` | доступ к `~/.claude` и `~/.codex` | `AgentFolderAccess` |
| `AgentUsageReading` | последний снимок лимитов агента | `FileAgentUsageReader` |
| `AgentActivityObserving` | записи агента в транскрипты | `FSEventsAgentActivitySource` |
| `Clock` | текущее время | `SystemClock`, `FixedClock` в тестах |

`Clock` — не педантизм: чистка истории «старше 7 дней» иначе не тестируется без ожидания в неделю.

### 3.1 Где архитектура окупается прямо здесь

Не абстрактная польза, а два конкретных места.

> **Поправка от 2026-08-13 — [ADR-0011](adr/0011-remove-music-module.md).** Модуля музыки
> в приложении больше нет. Примеры на `NowPlayingReading` ниже, а также разборы LSP и ISP
> в §5, оставлены как **учебные**: они показывают, зачем узкие порты и почему контракт —
> часть протокола. Искать эти типы в коде не надо, их там нет.

**Музыка.** В спецификации это главный риск: способ получения метаданных не определён и может отвалиться с обновлением ОС (§8.4 спеки). Разделение на три узких порта делает риск локальным.

```swift
// Domain
public protocol NowPlayingReading: Sendable {
  /// Возвращает `nil`, если источник метаданных недоступен.
  /// Реализация не имеет права подставлять заглушку вместо реальных данных.
  func currentTrack() async -> Track?
}

public protocol PlaybackControlling: Sendable {
  func toggle() async
  func next() async
  func previous() async
}
```

`MediaKeyAdapter` реализует **только** `PlaybackControlling` — метаданные он физически получить не может. `ScriptingBridgeAdapter` реализует все три, но работает лишь с Music.app и Spotify. Композит выбирает источник на лету:

```swift
// Data
public struct CompositeNowPlayingSource: NowPlayingReading, PlaybackControlling {
  private let metadataSources: [any NowPlayingReading]
  private let controller: any PlaybackControlling      // всегда MediaKeyAdapter как фолбэк

  public func currentTrack() async -> Track? {
    for source in metadataSources {
      if let track = await source.currentTrack() { return track }
    }
    return nil
  }
}
```

Когда Apple в очередной раз что-то закроет, меняется один адаптер. `Domain`, `Presentation` и вьюхи не трогаются. Если завтра появится публичный API — это ещё один адаптер, а не переписывание модуля.

**Перевод.** На macOS 14 фреймворка нет. `UnavailableTranslationAdapter` возвращает `.unsupported`, композиционный корень не регистрирует модуль в рейле. Ветвления по версии ОС внутри вью-моделей и вьюх не появляется.

---

## 4. Когда юзкейс заслуживает отдельного типа

Правило: **тип заводится, если внутри есть решение, инвариант или оркестрация двух и более портов.** Иначе вью-модель обращается к порту напрямую — правило зависимостей при этом не нарушается, порт всё так же объявлен в `Domain`.

**Заслуживают:**

| Юзкейс | Почему |
|---|---|
| `RecordPasteboardChange` | решает, сохранять ли вообще (конфиденциальные типы), классифицирует, пишет в два порта |
| `PruneExpiredClips` | инвариант «7 дней», согласованное удаление записи и блоба |
| `AddSnippet` | валидация по типу, нормализация, проверка дубликатов |
| `TranslateText` | отмена предыдущей задачи, определение языка, обработка недоступного пакета |
| `CopyScreenshot` | кладёт в пастборд два представления — URL и растр |

**Не заслуживают:**

```swift
// Плохо — тип ради типа
struct GetSnippetsUseCase {
  let store: any SnippetStoring
  func callAsFunction() async -> [Snippet] { await store.all() }
}

// Хорошо — вью-модель зовёт порт
@MainActor @Observable
final class SnippetsViewModel {
  private let store: any SnippetStoring
  private let addSnippet: AddSnippet          // а вот здесь решение есть — тип нужен
}
```

Оркестрация без решения — тоже не юзкейс. `DeleteScreenshot`, который просто зовёт `FileTrashing`, — лишний.

---

## 5. SOLID — на примерах проекта

Без учебных определений, только места, где принцип реально что-то меняет.

**SRP.** Соблазн — один `ClipboardManager`, который опрашивает пастборд, определяет тип, пишет в базу и отдаёт список вьюхе. Разделяется на четыре причины изменения:

| Тип | Меняется, когда |
|---|---|
| `PasteboardWatcher` | меняется частота опроса или условие паузы |
| `ClipKindDetector` | добавляется новый тип копии |
| `SQLiteClipStore` | меняется схема хранения |
| `ClipboardViewModel` | меняется поведение экрана |

**OCP.** Определение типа копии — цепочка правил, а не `switch` на восемь веток:

```swift
public protocol ClipKindRule: Sendable {
  func kind(for item: PasteboardItem) -> ClipKind?
}

public struct ClipKindDetector: Sendable {
  private let rules: [any ClipKindRule]   // порядок значим, см. §8.1 спеки
  public func detect(_ item: PasteboardItem) -> ClipKind {
    rules.lazy.compactMap { $0.kind(for: item) }.first ?? .text
  }
}
```

Девятый тип копии — новый `ClipKindRule` и строка в списке. Существующий код не редактируется.

**LSP.** Контракт `NowPlayingReading` явно требует возвращать `nil` при недоступности, а не подставлять заглушку. Без этого пункта в документации `MediaKeyAdapter` соблазнительно вернуть «Неизвестный трек», и вьюха, рассчитывающая скрыть блок метаданных, покажет мусор. Контракт — часть протокола, а не деталь реализации.

**ISP.** Ровно поэтому портов музыки четыре, а не один `MediaService`. Адаптер медиа-клавиш не может реализовать `NowPlayingReading` — и не должен быть вынужден это притворно делать.

**DIP.** Композиционный корень — единственное место, где встречаются конкретные типы:

```swift
// App/CompositionRoot.swift
@MainActor
func makeMusicViewModel() -> MusicViewModel {
  let bridge = ScriptingBridgeAdapter()
  let keys = MediaKeyAdapter()
  let source = CompositeNowPlayingSource(metadataSources: [bridge], controller: keys)
  return MusicViewModel(nowPlaying: source, playback: source,
                        volume: CoreAudioVolumeAdapter())
}
```

Синглтонов нет. `NSPasteboard.general`, `NSWorkspace.shared` и прочие глобальные точки доступа живут **только внутри адаптеров** и наружу не протекают.

---

## 6. DRY — что объединять, а что нет

**Не объединять.** `ClipItem` и `Snippet` оба имеют «значение + тип + копирование» и выглядят почти одинаково. Общего предка не заводить: у первого источником служит система и есть срок жизни, второй создаётся руками и живёт вечно. Они будут расходиться, а не сходиться. Совпадение формы — не дублирование знания.

**Объединять.** Реальные цели в этом проекте:

| Дубликат | Куда выносить |
|---|---|
| Строка списка `34 / 1fr / auto`, зазор 12 — в буфере и во вставках | `DesignSystem/ListRow` |
| Подтверждение копирования: тост + галочка на 1400 мс — в трёх модулях | `Presentation/CopyFeedback` |
| Иконочная кнопка 44×44 с hover-заливкой — везде | `DesignSystem/IconButton` |
| Токены цвета и типографики | `DesignSystem` — единственное место с литералами цвета |

Правило для дизайн-системы: **литерал цвета или размера вне `DesignSystem` — дефект.** Во вьюхах только `Palette.*` и `Metrics.*`.

---

## 7. Конкурентность

Swift 6 language mode со строгой проверкой — с первого дня. Включать её на готовом коде дороже, чем писать сразу.

- Все порты — `Sendable`.
- Хранилища — `actor` (`SQLiteClipStore`, `JSONSnippetStore`).
- Вью-модели — `@MainActor @Observable`.
- `Domain` не знает про `MainActor`: юзкейсы `async`, изоляцию задаёт вызывающая сторона.
- Опрос пастборда и Spotlight-запрос живут в акторе, наружу отдают через `AsyncStream`.

---

## 8. Стиль кода

**Google Swift Style Guide** — https://google.github.io/swift/

Практический источник истины — `swift-format` с конфигом в репозитории: его дефолты и есть этот гайд. Спорить о стиле в ревью запрещено, чинит форматтер.

### 8.1 Что отличается от привычек Xcode

| Правило | Значение | Замечание |
|---|---|---|
| Отступ | **2 пробела** | Xcode по умолчанию 4 — поменять в настройках проекта |
| Длина строки | **100 колонок** | |
| Точки с запятой | запрещены | |
| Импорты | по алфавиту, по одному, неиспользуемые удалять | |
| Trailing comma | обязательна в многострочных литералах | |
| `internal` | не писать, он по умолчанию | |
| `self.` | только там, где обязателен | |
| Force unwrap `!`, `try!` | запрещены, кроме доказуемо безопасных мест с комментарием-обоснованием | |
| Документация | `///` у каждого публичного объявления, первая строка — одно предложение | |
| Секции | `// MARK: -` | |
| Имена | по Swift API Design Guidelines, сокращений не вводить | |

### 8.2 Конфигурация

`.swift-format` в корне:

```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": { "spaces": 2 },
  "rules": {
    "AllPublicDeclarationsHaveDocumentation": true,
    "AlwaysUseLowerCamelCase": true,
    "NeverForceUnwrap": true,
    "NeverUseImplicitlyUnwrappedOptionals": true,
    "OrderedImports": true,
    "UseShorthandTypeNames": true,
    "ValidateDocumentationComments": true
  }
}
```

`NeverForceUnwrap` и `AllPublicDeclarationsHaveDocumentation` по умолчанию выключены — включаем осознанно.

SwiftLint добавляется только для того, чего `swift-format` не умеет: `cyclomatic_complexity`, `file_length`, `function_body_length`, `type_body_length`. Дублирующие правила стиля в нём отключить, иначе два инструмента будут спорить.

Хук pre-commit: `swift-format format --in-place --recursive Sources/` и `swift-format lint --strict`. В CI — `lint --strict` на весь репозиторий, падение сборки при нарушении.

### 8.3 Именование в проекте

| Сущность | Схема | Пример |
|---|---|---|
| Порт | герундий или существительное-роль | `ClipStoring`, `Clock` |
| Адаптер | технология + порт | `SQLiteClipStore`, `MediaKeyAdapter` |
| Юзкейс | глагол в повелительном наклонении | `AddSnippet`, `PruneExpiredClips` |
| Вью-модель | модуль + `ViewModel` | `ClipboardViewModel` |
| Вью | сущность + `View` / `Row` / `Card` | `ClipRow`, `ShotCard` |
| Фейк в тестах | `Fake` + порт | `FakeClipStore` |

Суффикс `Manager`, `Helper`, `Utils`, `Service` в именах типов не использовать: он ничего не сообщает и обычно означает нарушенный SRP.

---

## 9. Тестирование

Тестируемость — основная отдача от слоёв. Если её нет, архитектура не окупилась.

Инструмент — **Swift Testing** (`import Testing`, `@Test`, `#expect`), доступен с Xcode 16.

**Что покрывается обязательно** — весь `Domain`, без хост-приложения и без моков системных фреймворков:

| Юзкейс | Проверяем |
|---|---|
| `ClipKindDetector` | таблица «вход → тип» по всем восьми видам, включая порядок правил |
| `RecordPasteboardChange` | конфиденциальный тип не сохраняется; собственная запись не возвращается в историю |
| `PruneExpiredClips` | границы 7 дней на `FixedClock`; блоб удаляется вместе с записью |
| `AddSnippet` | таблица валидации по трём типам, нормализация тега, отказ дубликату без учёта регистра |
| `TranslateText` | быстрый повторный ввод отменяет предыдущую задачу; недоступный языковой пакет даёт `.unavailable`, а не ошибку |
| `CompositeNowPlayingSource` | при пустых метаданных возвращает `nil`, управление при этом остаётся рабочим |

**Что не покрывается юнит-тестами.** Адаптеры (`NSPasteboard`, Spotlight, ScriptingBridge, CoreAudio) — тонкие обёртки без логики; проверяются интеграционно или вручную по чеклисту приёмки спеки. Если в адаптере появился `if` с бизнес-смыслом — он попал не в тот слой.

Фейки портов живут в `FlowbarTestSupport` и переиспользуются, а не пишутся заново в каждом файле тестов.

---

## 10. Definition of Done

Перед мержем:

- [ ] Сборка проходит в Swift 6 language mode без предупреждений конкурентности
- [ ] `swift-format lint --strict` чист
- [ ] `Domain` не импортирует ничего, кроме `Foundation` (проверяется компилятором — см. §2.1)
- [ ] Новый системный API обёрнут портом, конкретный тип не протёк в `Presentation`
- [ ] Новый тип в `Domain` покрыт тестами; в фейках нет логики
- [ ] Публичные объявления задокументированы, у контрактов с неочевидным поведением описан контракт (как в `LaunchAtLoginControlling.setEnabled`: возвращает фактическое состояние, а не запрошенное)
- [ ] Ни одного литерала цвета или размера вне `DesignSystem`
- [ ] Нет новых синглтонов; зависимости пришли через инициализатор
- [ ] Если заведён новый тип юзкейса — внутри есть решение, инвариант или два порта (§4)
