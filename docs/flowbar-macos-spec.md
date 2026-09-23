# Flowbar для macOS — спецификация реализации

Источник истины по визуалу: `notch-command-center-v2.html`. Все числа ниже сняты из него, а не восстановлены по памяти. Единицы CSS `px` соответствуют `pt` в AppKit/SwiftUI 1:1 (на Retina это 2 физических пикселя).

Источник истины по архитектуре и стилю кода: `flowbar-engineering-guidelines.md`. Этот документ описывает **что** реализуется, регламент — **как**. При расхождении приоритет у регламента.

---

## 1. Что это

Резидентная утилита без окна в Dock. Живёт в области notch: свёрнутая «пилюля» висит под вырезом, при наведении разворачивается в панель с пятью модулями.

| Модуль | Назначение |
|---|---|
| Буфер | История копирований с иконкой по типу и копированием в один клик |
| Снимки | Горизонтальная лента последних скриншотов, клик копирует, крестик удаляет |
| Перевод | Двухпанельный переводчик, запуск по debounce |
| Музыка | Плеер системного аудио без очереди |
| Быстрые вставки | Часто используемые email / теги / номера |

**Не входит в объём v1:** синхронизация между устройствами, облако, история переводов, редактор скриншотов, настройки (кнопка-шестерёнка в рейле — заглушка).

---

## 2. Платформа и стек

| Параметр | Значение | Почему |
|---|---|---|
| Минимальная ОС | **macOS 14 Sonoma** | `NSScreen.safeAreaInsets` и `auxiliaryTopLeftArea` стабильны с 12, но SwiftUI-анимации размера окна и `.onHover` до 14 ведут себя неровно |
| Модуль перевода | **macOS 15 Sequoia** | `Translation` framework доступен с 15.0; на 14 модуль скрывается из рейла |
| UI | SwiftUI внутри `NSHostingView` | Вёрстка панели декларативная, но окно должно быть кастомным `NSPanel` — SwiftUI `Window`/`MenuBarExtra` нужного поведения не дают |
| Архитектура | Чистая архитектура, слои — отдельные таргеты SPM | Правила и калибровка — `flowbar-engineering-guidelines.md` |
| Стиль кода | Google Swift Style Guide, `swift-format` | Конфиг и хуки — регламент §8 |
| Язык | Swift 6 language mode, строгая конкурентность | Включать на готовом коде дороже |
| Зависимости | GRDB (SQLite) — по желанию | Всё остальное системное |

Приложение — **agent app**: `LSUIElement = true` в `Info.plist`, иконки в Dock нет, главного меню нет.

---

## 3. Оконная архитектура — главное

Это самая нетривиальная часть. Ошибка здесь ломает всё остальное.

### 3.1 Одно окно, а не два

Свёрнутая пилюля и развёрнутая панель — **одно окно постоянного размера**, равного развёрнутому состоянию плюс поле под тень. Менять размер окна на hover нельзя: NSWindow не анимирует `setFrame` синхронно с содержимым, будет рассинхрон и мерцание.

```swift
final class NotchPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false              // тень рисуем в SwiftUI по силуэту
        level = .statusBar             // выше строки меню
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
    }
    override var canBecomeKey: Bool { true }   // нужно для ввода в переводчике и вставках
    override var canBecomeMain: Bool { false }
}
```

`.nonactivatingPanel` обязателен: без него клик по панели заберёт фокус у активного приложения, и «скопировать → вставить в редактор» перестанет работать как единый жест.

`canBecomeKey = true` нужен, чтобы `TextField` принимал ввод. Ключевым окно станет только при явном клике в поле — `.nonactivatingPanel` не активирует само приложение.

### 3.2 Hit-testing — как hover открывает панель

Окно всегда большое, но кликабельно только там, где нарисован чёрный силуэт. Иначе прозрачная область перехватит клики по приложению под ней.

```swift
final class ShapeHitTestView: NSView {
    var visibleShape: () -> NSRect = { .zero }   // текущий силуэт в координатах view
    override func hitTest(_ point: NSPoint) -> NSView? {
        visibleShape().contains(point) ? super.hitTest(point) : nil
    }
}
```

`visibleShape` возвращает:
- **свёрнуто** — прямоугольник пилюли `collapsedWidth × 38`, центрированный по горизонтали, прижатый к верху;
- **развёрнуто** — объединение пилюли и панели.

Форму нужно обновлять по факту завершения анимации, а не в её начале, иначе при сворачивании курсор «провалится» сквозь ещё видимую панель.

Наведение отслеживается `NSTrackingArea` с `[.mouseEnteredAndExited, .activeAlways, .inVisibleRect]` на этом же view. SwiftUI `.onHover` использовать не стоит — он не знает про кастомный `hitTest` и будет срабатывать на прозрачных областях.

### 3.3 Закрепление (pin)

Без закрепления панель схлопнется, как только курсор уйдёт — а он уйдёт, пока пользователь печатает в переводчике. Логика из прототипа:

| Событие | Действие |
|---|---|
| `mouseEntered` | развернуть |
| `mouseExited` и не закреплено | свернуть |
| клик по пилюле | переключить закрепление |
| любой клик или получение фокуса внутри панели | закрепить |
| `Esc`, клик вне окна, кнопка-шеврон | снять закрепление и свернуть |

Клик вне окна ловится `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`. Глобальный монитор не требует Accessibility, если не нужен перехват.

### 3.4 Геометрия notch

```swift
extension NSScreen {
    var notchWidth: CGFloat? {
        guard safeAreaInsets.top > 0,
              let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else { return nil }
        return frame.width - left.width - right.width
    }
}
```

Ширина свёрнутой пилюли = `max((notchWidth ?? 0) + 2 × 14, 218)`: крыло слева от выреза не уже 14 pt, чтобы индикатору агентов было где стоять (ADR-0013). На Mac без выреза (внешний монитор, старые модели) вырез отсутствует — пилюля просто висит по центру верха экрана шириной 218.

Отслеживать нужно `NSApplication.didChangeScreenParametersNotification` и пересоздавать/перепозиционировать окно: пользователь подключает монитор, меняет разрешение, закрывает крышку.

**Решение принять:** на каком экране жить, если их несколько. Рекомендация — на экране со встроенным вырезом, иначе на `NSScreen.main`.

### 3.5 Цвет корпуса

В макете фон панели `#08090a`. Физический вырез MacBook — **чистый чёрный**. Если оставить `#08090a`, на реальном железе будет видна граница между пилюлей и вырезом.

**Рекомендация:** на экране с вырезом рисовать корпус в `NSColor.black` (`#000000`); `#08090a` оставить только для экранов без выреза, где панели не с чем сливаться и абсолютный чёрный выглядит провалом. Остальные токены не меняются — разница в одну ступень яркости на границе не видна.

---

## 4. Токены

Копируются один в один из `:root` артефакта. Держать в одном файле `DesignTokens.swift`, не рассыпать по вьюхам.

```swift
enum Palette {
    static let bg          = Color(hex: 0x08090A)   // корпус (см. 3.5)
    static let surface     = Color(hex: 0x191A1B)   // всплывашки, тост
    static let fg          = Color(hex: 0xF7F8F8)   // основной текст
    static let fg2         = Color(hex: 0xD0D6E0)   // вторичный
    static let muted       = Color(hex: 0x8A8F98)   // метаданные, иконки в покое
    static let border      = Color.white.opacity(0.08)
    static let borderSoft  = Color.white.opacity(0.05)
    static let accent      = Color(hex: 0x5E6AD2)   // только primary-кнопка
    static let accentOn    = Color.white
    static let accentHover = Color(hex: 0x828FFF)   // активный пункт рейла
    static let accentPress = Color(hex: 0x4752C4)
    static let success     = Color(hex: 0x27A644)
    static let danger      = Color(hex: 0xDC2626)
}
```

Токен `--meta` (`#62666D`) в макете **не используется для текста** — он даёт 1.99:1 на чёрном и был заменён на `muted` по всему интерфейсу. Не возвращать его в текстовые стили.

### Заливки состояний

Глубина на чёрном строится не тенями, а ступенями белой прозрачности:

| Состояние | Заливка |
|---|---|
| Покой карточки/строки | `.clear` |
| Hover строки списка | `Color.white.opacity(0.05)` + рамка `borderSoft` |
| Hover иконочной кнопки | `Color.white.opacity(0.09)` |
| Hover карточки скриншота | `Color.white.opacity(0.06)` + рамка `border` |
| Нажатие | `Color.white.opacity(0.10)` |
| Активный пункт рейла | `Color.white.opacity(0.05)` + `accentHover` на иконке |

**Правило контраста:** при смене состояния текст и иконки не должны темнеть. Меняется только фон. Ни одно hover-состояние не переводит `fg` в `muted`.

### Радиусы

`sm 6` (кнопки, поля) · `md 8` (карточки, строки) · `lg 12` (панели) · `pill 9999` · пилюля notch — `0 0 20 20`.

---

## 5. Типографика

Гарнитура — **Inter Variable** с включёнными OpenType-фичами `cv01` и `ss03`. Это не косметика: без них получается обычный Inter, а не тот рисунок, что в макете. SF Pro не подходит — этих фич в ней нет.

Inter под SIL OFL 1.1, бандлить в приложение можно. Класть `.ttf` (variable) в бандл, регистрировать через `ATSApplicationFontsPath` в `Info.plist`.

```swift
extension NSFont {
    static func inter(size: CGFloat, weight: CGFloat) -> NSFont {
        let base = NSFontDescriptor(fontAttributes: [.name: "InterVariable"])
        let descriptor = base
            .addingAttributes([
                kCTFontVariationAttribute as NSFontDescriptor.AttributeName: [
                    0x77676874: weight            // 'wght'
                ],
                .featureSettings: [
                    [NSFontDescriptor.FeatureKey.typeIdentifier: 0x63763031,   // 'cv01'
                     NSFontDescriptor.FeatureKey.selectorIdentifier: 1],
                    [NSFontDescriptor.FeatureKey.typeIdentifier: 0x73733033,   // 'ss03'
                     NSFontDescriptor.FeatureKey.selectorIdentifier: 1]
                ]
            ])
        return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size)
    }
}
```

Точное написание тегов фич проверить на реальном билде — Core Text принимает их и через `kCTFontOpenTypeFeatureTag` в виде строки, этот путь надёжнее.

**Три веса, больше не нужно:** 400 читать · **510 — рабочий вес интерфейса** · 590 заголовки и кнопки. 700 не использовать.

Моноширинный — Berkeley Mono, при отсутствии `SF Mono` / `ui-monospace`.

### Шкала

| Роль | Размер | Вес | Трекинг | Где |
|---|---|---|---|---|
| Название трека | 22 | 590 | −0.02em | плеер |
| Язык | 13 | 590 | −0.01em | переводчик |
| Поле ввода перевода | 16 | 400 | 0 | переводчик |
| Строка списка | 13 | 510 | 0 | буфер, вставки |
| Имя скриншота | 12 | 510 | 0 | лента |
| Метаданные | 11 | 400 | 0 | под строками |
| Подписи, чипы | 10–11 | 400–510 | 0 | время, размеры |
| Надзаголовок CAPS | 10 | 400 | **+0.08em** | «СДЕЛАТЬ СНИМОК» |

Прописные без положительного трекинга — самая заметная ошибка вёрстки. `+0.08em` обязателен.

---

## 6. Геометрия

### Корпус

| Элемент | Значение |
|---|---|
| Пилюля свёрнутая | `max(notchWidth + 2 × 14, 218) × 38`, радиус `0 0 20 20`. Слагаемое `2 × 14` — минимальное крыло под индикатор агентов, ADR-0013; на Mac16,7 не срабатывает |
| Индикатор агентов | точки 6 pt в левом крыле свёрнутой пилюли, столбиком с зазором 5; пульсация прозрачности 1 → 0,65, период 1,6 с — §8.6 |
| Пилюля развёрнутая | `760 × 38`, радиус 0 |
| Панель | `760 × 380`, радиус `0 0 22 22` |
| Полная высота развёрнутого блока | **418** |
| Тень силуэта | `drop-shadow(0 20 44 rgba(0,0,0,.58))` |
| Ширина на узком экране | `min(760, ширина экрана − 20)` |
| Высота на низком экране | `min(380, высота экрана − 84)` |

### Рейл — 60 pt

Сверху вниз: паддинг 14 → логотип 17×17 → **отступ 18** → 5 кнопок 44×44 с шагом **4** → распорка → шестерёнка 44×44 → паддинг 12.

Отступ логотипа до кнопок (18) намеренно в 4,5 раза больше шага между кнопками (4) — так логотип читается как отдельный уровень, а не как шестая кнопка. Не выравнивать.

Активный пункт: иконка `accentHover` + полоска `2 × 20`, радиус `0 2 2 0`, прижата к левому краю рейла.

Подсказка при наведении — справа от кнопки, `left = 100% + 6`, фон `surface`, в ней название и шорткат моноширинным 10 pt.

Минимальная высота рейла — **339**. Это нижний предел высоты панели: ниже 350 навигацию придётся перекомпоновывать.

### Контентная область

Паддинг `12 / 14 / 14`. Полезная высота — **354**.

| Экран | Занимает | Запас |
|---|---|---|
| Снимки | 326 | 28 |
| Музыка | 280 | 74 |
| Перевод (шапка + футер, поле тянется) | 118 | 236 |
| Буфер, Вставки | скроллятся | — |

### Размеры контролов

| Контрол | Размер |
|---|---|
| Кнопка рейла, иконочная кнопка, кнопка плеера | 44 × 44 |
| Play | 48 × 48, заливка `fg`, иконка `bg` |
| Строка буфера / вставки | высота 62 / 60, сетка `34 / 1fr / auto`, зазор 12 |
| Карточка скриншота | ширина 238, превью 126, паддинг 6 |
| Крестик удаления | 26 × 26, инсет 13 от края карточки (6 от края превью) |
| Строка добавления вставки | высота 34 у всех трёх контролов, зазор 6 |
| Чип шортката | мин. ширина 58, высота 26 |
| Обложка | 140 × 140, радиус 12 |

Строка добавления (34 pt) и крестик (26 pt) ниже рекомендованных Apple 44 pt. Для десктопной утилиты это норма (`NSControl` regular — 32 pt), но если появится сборка под iPad/Catalyst — вернуть к 44.

---

## 7. Анимация разворота

| Параметр | Значение |
|---|---|
| Длительность разворота/сворачивания | **340 мс** |
| Кривая | `cubic-bezier(0.2, 0, 0, 1)` → `.timingCurve(0.2, 0, 0, 1, duration: 0.34)` |
| Быстрые переходы (hover, цвет) | 150 мс |
| Средние (тост) | 200 мс |
| Задержка появления содержимого | **110 мс** после начала разворота |
| Содержимое | `opacity 0→1`, `offset y −8→0` |

Одновременно анимируются: ширина пилюли `218 → 760`, её нижний радиус `20 → 0`, выравнивание содержимого пилюли `center → space-between`, высота панели `0 → 380`.

Панель растёт **высотой от нуля**, а не проявляется прозрачностью — это то, что делает жест похожим на разворачивание физического выреза. В SwiftUI: контейнер с `.frame(height: isExpanded ? 380 : 0)` и `.clipped()`.

При `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` — переход мгновенный, состояние переключается без анимации.

---

## 8. Модули

### 8.1 Буфер обмена

```swift
struct ClipItem: Identifiable {
    let id: UUID
    let kind: ClipKind          // text, link, code, image, color, address, path, value
    let preview: String         // одна строка, обрезается многоточием
    let payload: Payload        // .string(String) | .imageFile(URL)
    let sourceApp: String       // "Notes", "Safari", "VS Code"
    let capturedAt: Date
}
```

**Захват.** Уведомления об изменении пастборда в macOS нет. Опрашивать `NSPasteboard.general.changeCount` таймером **200–500 мс**. Таймер ставить на паузу, когда пишем в пастборд сами, иначе получим собственную запись обратно.

**Что не сохранять.** Уважать конвенцию nspasteboard.org — пропускать элементы с типами `org.nspasteboard.ConcealedType` (пароли из менеджеров) и `org.nspasteboard.TransientType`. Без этого первый же пароль из 1Password окажется в истории. Дополнительно вести чёрный список bundle id.

**Определение типа** — по порядку, первое совпадение:

1. `NSPasteboard.PasteboardType.fileURL` → `path`
2. `.png` / `.tiff` → `image`
3. Строка проходит `NSDataDetector(.link)` целиком → `link`
4. Строка матчит `#?[0-9a-f]{3,8}` / `rgb(` / `oklch(` → `color`
5. `NSDataDetector(.address)` → `address`
6. Есть `{}`, `;`, `=>`, отступы или source-app из списка редакторов → `code`
7. Иначе → `text`

Пункт 6 — эвристика, ошибки не критичны: тип влияет только на иконку.

**Источник.** `NSWorkspace.shared.frontmostApplication?.localizedName` в момент срабатывания таймера. Точность не стопроцентная, для метки достаточно.

**Хранение.** Метаданные — SQLite. Изображения — файлами в `~/Library/Application Support/Flowbar/clips/`, в БД только путь. Чистка при старте и раз в час: `capturedAt < now − 7 дней`, файлы удалять вместе с записями.

**Копирование по кнопке.** Записать в пастборд, показать тост, на 1400 мс подменить иконку на галочку.

**Решение принять:** нужна ли автовставка (`⌘V` в активное приложение после копирования). Она требует Accessibility, а значит — отказ от App Sandbox и от App Store. См. §10.

### 8.2 Снимки экрана

**Не хранит файлы.** Модуль читает файловую систему.

**Где искать.** `UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")`, по умолчанию `~/Desktop`.

**Как находить.** `NSMetadataQuery` со Spotlight-предикатом:

```swift
query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
query.searchScopes = [screenshotFolderURL]
query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)]
```

`kMDItemIsScreenCapture` — системный атрибут, ставится самим `screencapture`. Живые обновления приходят через `NSMetadataQueryDidUpdate`. Это надёжнее, чем `FSEventStream` по расширению файла: не поймает посторонние png.

Ограничение выборки — 30 последних. Размеры брать из `kMDItemPixelWidth`/`kMDItemPixelHeight`, вес — из `NSURLFileSizeKey`.

**Превью.** `QLThumbnailGenerator` в размер `224 × 126 @2x`, кэш в память по `url + mtime`.

**Клик — копирование.** Класть в пастборд и файл, и растр:

```swift
pasteboard.clearContents()
pasteboard.writeObjects([url as NSURL])          // для Finder и почты
pasteboard.setData(pngData, forType: .png)       // для редакторов
```

Подтверждение — рамка карточки `success` на 900 мс + тост.

**Крестик — удаление.** Только `NSWorkspace.shared.recycle([url])`, в Корзину. Никаких `FileManager.removeItem`: пользователь удаляет чужой файл, который он не создавал через это приложение.

**Шорткаты внизу экрана** — статический список, не настраивается: ⇧⌘4 область · ⇧⌘3 весь экран · ⇧⌘5 панель захвата. Это системные сочетания macOS; читать их фактические значения из `com.apple.symbolichotkeys` — оверинжиниринг для v1.

### 8.3 Перевод

**Движок.** `Translation` framework, macOS 15+. Работа на устройстве, без сети, языковые пакеты скачиваются системой по запросу.

```swift
.translationTask(source: sourceLang, target: targetLang) { session in
    let response = try await session.translate(sourceText)
    translated = response.targetText
}
```

Языковые пакеты требуют явного согласия пользователя — система показывает свой диалог при первом обращении к паре языков. Отработать отказ: показать в поле статуса «язык не загружен».

На macOS 14 модуль недоступен — прятать кнопку из рейла, а не показывать неработающую.

**Запуск.** По debounce **700 мс** после последнего нажатия клавиши. Кнопки «Перевести» нет.

Статус в шапке правой панели, три состояния: `печатаю…` → `перевод…` → `готово`. Пустой ввод даёт `ожидание ввода` и чистит результат.

Каждый новый ввод отменяет предыдущую задачу — иначе результат «догонит» и перезапишет свежий перевод. Хранить `Task` и звать `cancel()`.

**Определение языка** — `NLLanguageRecognizer`, результат показывается меткой «определён» рядом с селектором исходного языка.

**Смена языков** меняет местами и языки, и содержимое полей, затем запускает перевод заново.

### 8.4 Музыка — главный технический риск

**Проблема.** Публичного API, чтобы прочитать «что играет в системе», в macOS нет. `MPNowPlayingInfoCenter` отдаёт только то, что публикует ваше собственное приложение.

Приватный `MediaRemote.framework` (`MRMediaRemoteGetNowPlayingInfo`) исторически решал задачу, но Apple закрыла его приватным entitlement примерно в macOS 15.4. **Проверьте на актуальной версии перед тем, как закладываться.** С App Store он несовместим в любом случае.

**Три пути:**

| Путь | Метаданные | Управление | Цена |
|---|---|---|---|
| **A. MediaRemote (приватный)** | полные, любое приложение | полное | ломается с обновлением ОС, App Store закрыт |
| **B. ScriptingBridge к Music.app и Spotify** | полные, но только эти два | полное | нужно разрешение «Автоматизация», не покрывает браузер и остальных |
| **C. Системные медиа-клавиши** | **нет** | play/pause/next/prev в любом приложении | работает всегда, публично |

**Рекомендация для v1: B + C.** ScriptingBridge даёт обложку, название и артиста для Music.app и Spotify — это покрывает подавляющее большинство сценариев. Медиа-клавиши работают как универсальный фолбэк, когда играет что-то другое: тогда экран показывает только транспорт без метаданных, с честной подписью источника.

Отправка медиа-клавиши:

```swift
func sendMediaKey(_ key: Int32) {  // NX_KEYTYPE_PLAY = 16, NEXT = 17, PREVIOUS = 18
    for isDown in [true, false] {
        let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xA00 : 0xB00)
        let data1 = Int((key << 16) | ((isDown ? 0xA : 0xB) << 8))
        guard let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1, data2: -1) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
```

**Прогресс трека.** Через ScriptingBridge — `player position`, опрос раз в секунду. Через медиа-клавиши — недоступен: полосу прогресса скрывать, а не показывать нулевой.

**Громкость.** Системная громкость — CoreAudio (`AudioObjectSetPropertyData` на `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`), не громкость приложения. В макете это именно системный ползунок.

**Устройство вывода** в чипе — `AudioObjectGetPropertyData` для `kAudioHardwarePropertyDefaultOutputDevice`, имя через `kAudioObjectPropertyName`.

### 8.5 Быстрые вставки

```swift
struct Snippet: Identifiable, Codable {
    let id: UUID
    var kind: SnippetKind   // email, tag, phone
    var value: String
    var note: String        // необязательная подпись
}
```

Хранение — JSON в Application Support. Объём микроскопический, БД не нужна.

**Валидация при добавлении:**

| Тип | Правило | Нормализация | Сообщение об ошибке |
|---|---|---|---|
| Email | `^[^\s@]+@[^\s@]+\.[^\s@]+$` | trim | «Похоже, это не адрес почты — нужен формат name@example.com» |
| Тег | длина > 1, без пробелов | добавить `#`, если нет ни `#`, ни `@` | «Тег не должен содержать пробелов» |
| Номер | `^\+?[\d\s()-]{6,}$` | схлопнуть пробелы | «В номере допустимы только цифры, пробелы, «+», «(» и «-»» |

Дубликаты (без учёта регистра) отклоняются: «Такая вставка уже есть в списке». Ошибка окрашивает рамку поля в `danger` и подменяет строку подсказки под формой; сбрасывается при первом же вводе.

Новая вставка добавляется в начало списка. У каждой строки — копирование и удаление.

Плейсхолдер поля меняется вместе с выбранным типом: `name@example.com` / `#design-review` / `+7 900 000-00-00`.

### 8.6 Лимиты агентов и индикатор работы

Решения и замеры — ADR-0012 (лимиты) и ADR-0013 (индикатор).

**Экран «Лимиты».** Пятый пункт рейла. Для Claude Code и Codex — окна лимита (5 часов, неделя): израсходованная доля, время сброса, полоса, возраст снимка. Полосы — в цвете агента, как его точка в пилюле; от 90 % подпись и полоса — `danger`.

| Агент | Источник | Пустое состояние |
|---|---|---|
| Codex | последняя запись `rate_limits` в свежем `~/.codex/sessions/**/rollout-*.jsonl` | «Codex запишет лимиты на первом ходу сессии» |
| Claude Code | `~/.claude/flowbar-usage.json`, который пишет statusLine-команда | кнопка «Скопировать настройку» кладёт в буфер блок `statusLine` для `settings.json` |

Доступ к `~/.claude` и `~/.codex` — security-scoped bookmark, выбор папки один раз. Выбор чужой папки не сохраняется: папка узнаётся по каталогу транскриптов внутри. Файлы читаются при открытии экрана и раз в 10 с, пока он открыт.

**Индикатор в пилюле.** Агент считается работающим 20 с после последней записи в транскрипт (`~/.claude/projects`, `~/.codex/sessions`), наблюдение — FSEvents. Точка: Claude Code — `#D97757`, Codex — `#4C8DFF`; оба — столбиком, Claude сверху. Только в свёрнутом виде. Никто не работает — в крыле пусто. Без выданного доступа индикатор молчит.

---

## 9. Глобальные хоткеи

| Сочетание | Действие |
|---|---|
| ⌥Space | Развернуть/свернуть панель |
| ⌘⇧V | Развернуть на вкладке «Буфер» |
| ⌥T | Развернуть на вкладке «Перевод», фокус в поле |
| Esc | Свернуть |

Регистрация — Carbon `RegisterEventHotKey`. Он не требует Accessibility, в отличие от `CGEventTap`. API старый, но не депрекейтнутый и остаётся штатным способом для глобальных сочетаний.

⇧⌘3/4/5 не перехватывать — это системные сочетания, они и должны оставаться системными.

---

## 10. Разрешения, entitlements, дистрибуция

| Возможность | Что нужно | Совместимо с App Sandbox |
|---|---|---|
| Чтение пастборда | ничего | да |
| Папка со скриншотами | `com.apple.security.files.user-selected.read-write` + security-scoped bookmark, папку пользователь выбирает один раз | да |
| Удаление в Корзину | тот же bookmark | да |
| Music.app / Spotify | `com.apple.security.automation.apple-events` + `NSAppleEventsUsageDescription` | да |
| Медиа-клавиши | ничего | да |
| Перевод | ничего | да |
| Глобальные хоткеи | ничего | да |
| **Автовставка ⌘V** | **Accessibility** | **нет** |
| **MediaRemote** | приватный entitlement | **нет** |

**Развилка дистрибуции.** Без автовставки и без MediaRemote приложение помещается в App Sandbox и проходит в App Store. С ними — только Developer ID + нотаризация, вне магазина.

Рекомендация: **начинать без них**, оставив автовставку опцией на будущее. Копирование в один клик покрывает основной сценарий, а требование Accessibility при первом запуске заметно бьёт по конверсии.

Обязательные ключи `Info.plist`: `LSUIElement = true`, `NSAppleEventsUsageDescription`, `ATSApplicationFontsPath`.

---

## 11. Доступность

- Каждая кнопка рейла — `accessibilityLabel` из названия модуля, `accessibilityAddTraits(.isSelected)` для активной.
- Кнопки копирования — «Скопировать <тип>», не «Кнопка».
- Крестик — «Удалить снимок <имя>», обязательно с именем: без него в VoiceOver шесть одинаковых кнопок.
- Крестик появляется по hover **и по фокусу** карточки — иначе с клавиатуры удалить нельзя.
- Тост — `accessibilityAnnouncement`, чтобы озвучивался результат копирования.
- Фокус: видимое кольцо на всех интерактивных элементах, `accent` с прозрачностью 30% толщиной 2.
- Reduce Motion — см. §7. Точка агента в пилюле при нём горит ровно, без пульсации.
- Индикатор агентов — один элемент с меткой «Claude Code работает», «Codex работает» или «Claude Code и Codex работают»; когда никто не работает, его нет в дереве.
- Increase Contrast (`accessibilityDisplayShouldIncreaseContrast`) — поднимать `border` с 8% до 20%, `borderSoft` с 5% до 12%.

---

## 12. Структура проекта

Слои и правило зависимостей — `flowbar-engineering-guidelines.md` §2. Здесь только раскладка файлов. Каждый слой — отдельный таргет SPM, поэтому запрещённый импорт не соберётся.

```
Flowbar/
├─ Package.swift                    // таргеты слоёв, регламент §2.1
├─ .swift-format                    // Google Swift Style Guide, регламент §8.2
│
├─ Sources/
│  ├─ FlowbarDomain/                // импортирует только Foundation
│  │  ├─ Entities/                  // ClipItem, Screenshot, Snippet, AgentUsage
│  │  ├─ Ports/                     // протоколы из регламента §3
│  │  └─ UseCases/                  // RecordPasteboardChange, PruneExpiredClips,
│  │                                // AddSnippet, TranslateText, CopyScreenshot,
│  │                                // AgentUsageParser, AgentActivity
│  │
│  ├─ FlowbarData/                  // реализации портов
│  │  ├─ Pasteboard/                // NSPasteboardAdapter
│  │  ├─ Clips/                     // SQLiteClipStore, FileSystemBlobStore
│  │  ├─ Screenshots/               // SpotlightScreenshotSource,
│  │  │                             // QuickLookThumbnailRenderer, WorkspaceTrashAdapter
│  │  ├─ Translation/               // AppleTranslationAdapter, UnavailableTranslationAdapter
│  │  ├─ Music/                     // ScriptingBridgeAdapter, MediaKeyAdapter,
│  │  │                             // CompositeNowPlayingSource, CoreAudioVolumeAdapter
│  │  ├─ Snippets/                  // JSONSnippetStore
│  │  └─ Agents/                    // AgentFolderAccess, FileAgentUsageReader,
│  │                                // FSEventsAgentActivitySource
│  │
│  ├─ FlowbarPresentation/          // импортирует только Domain
│  │  ├─ Shell/                     // ShellState: isExpanded, isPinned, activeModule
│  │  ├─ CopyFeedback.swift         // общее подтверждение копирования, регламент §6
│  │  └─ ViewModels/                // по одной на модуль
│  │
│  ├─ FlowbarDesignSystem/          // единственное место с литералами цвета и размеров
│  │  ├─ Palette.swift
│  │  ├─ Typography.swift           // Inter + cv01/ss03, §5
│  │  ├─ Metrics.swift              // геометрия из §6
│  │  └─ Components/                // ListRow, IconButton, RailButton, Toast, KeyChip
│  │
│  ├─ FlowbarUI/                    // SwiftUI + AppKit-оболочка
│  │  ├─ Shell/                     // NotchPanel, ShapeHitTestView, NotchGeometry,
│  │  │                             // NotchShellView, AgentActivityIndicator — §3
│  │  └─ Modules/                   // ClipboardView, ScreenshotStripView, TranslateView,
│  │                                // SnippetsView, LimitsView
│  │
│  └─ FlowbarTestSupport/           // фейки портов для тестов
│
├─ Tests/
│  └─ FlowbarDomainTests/           // регламент §9
│
└─ App/                             // Xcode-таргет приложения
   ├─ FlowbarApp.swift              // @main, LSUIElement
   ├─ CompositionRoot.swift         // единственное место, где встречаются конкретные типы
   ├─ HotKeyCenter.swift            // §9 спеки
   └─ Resources/Fonts/InterVariable.ttf
```

Системные API модулей (§8) живут исключительно в `FlowbarData`. `NSPasteboard`, `NSWorkspace`, `NSMetadataQuery`, `ScriptingBridge`, CoreAudio и `Translation` не должны встречаться нигде выше этого слоя.

---

## 13. Соответствие макету

В HTML проставлены `data-od-id` — по ним элементы макета сопоставляются с вьюхами:

| `data-od-id` | Вью |
|---|---|
| `notch-command-center` | `NotchShellView` |
| `notch-bar`, `notch-toggle`, `collapse-panel` | `NotchBarView` |
| `sidebar-rail`, `rail-logo`, `rail-*` | `RailView`, `RailButton` |
| `clipboard-history`, `clip-row-*` | `ClipboardListView`, `ClipRow` |
| `screenshots-strip`, `shot-*` | `ScreenshotStripView`, `ShotCard` |
| `capture-shortcuts` | `CaptureHintsView` |
| `translator-source`, `translator-result`, `swap-languages` | `TranslateView` |
| `music-player`, `play-pause`, `track-progress`, `volume-control` | `PlayerView` |
| `snippet-form`, `snippet-list`, `snippet-add` | `SnippetsView` |

---

## 14. Критерии приёмки

**Корпус**
- [ ] Свёрнутая пилюля визуально неотличима от физического выреза — границы не видно
- [ ] Клик мимо силуэта попадает в приложение под панелью, а не в панель
- [ ] Наведение разворачивает панель за 340 мс без рывка на первом кадре
- [ ] Уход курсора при незакреплённой панели сворачивает её; при вводе текста — нет
- [ ] Клик по панели не забирает фокус у активного приложения
- [ ] Панель остаётся на месте при переключении Space и в полноэкранном режиме
- [ ] Подключение внешнего монитора не ломает позиционирование

**Модули**
- [ ] Пароль, скопированный из менеджера, в историю не попадает
- [ ] Тип копии определяется верно для восьми поддерживаемых видов
- [ ] Новый скриншот появляется в ленте без перезапуска приложения
- [ ] Удаление скриншота кладёт файл в Корзину, а не стирает
- [ ] Перевод стартует через 700 мс после остановки ввода; быстрый повторный ввод отменяет предыдущий запрос
- [ ] Плеер управляет воспроизведением в приложении, которого нет в списке поддерживаемых
- [ ] Невалидный email не добавляется и даёт понятное сообщение
- [ ] Лимиты Codex видны сразу после выбора `~/.codex`, без установки чего-либо
- [ ] Claude Code до установки statusLine честно показывает «нет данных», а не нули
- [ ] Работа агента зажигает его точку в пилюле не позже чем через 2 с, тишина 20 с её гасит

**Оформление**
- [ ] Ни один текст не темнеет при наведении
- [ ] Прописные набраны с трекингом +0.08em
- [ ] Активный пункт рейла — единственное акцентное пятно на экране (кроме экрана вставок, где второе — кнопка «Добавить», и экрана лимитов, где полосы окрашены в цвета агентов)
- [ ] При включённом Reduce Motion переходы мгновенные
- [ ] Все кнопки достижимы с клавиатуры и показывают кольцо фокуса

**Архитектура** (развёрнуто — регламент §10)
- [ ] `FlowbarDomain` собирается, импортируя только `Foundation`
- [ ] Ни один системный API модулей не встречается выше слоя `FlowbarData`
- [ ] Юзкейсы `Domain` покрыты тестами без хост-приложения
- [ ] `swift-format lint --strict` чист, сборка в Swift 6 mode без предупреждений конкурентности
- [ ] Литералов цвета и размеров вне `FlowbarDesignSystem` нет

---

## 15. Что нужно решить до старта

1. **Музыка** — проверить статус MediaRemote на целевой версии macOS и зафиксировать путь A/B/C. От этого зависит, будет ли экран показывать метаданные всегда или только для Music.app и Spotify. Решение обратимо: порты `NowPlayingReading` / `PlaybackControlling` разделены так, что смена пути затрагивает один адаптер (регламент §3.1), поэтому старт разработки этого не ждёт.
2. **Дистрибуция** — App Store или Developer ID. Определяет, войдут ли автовставка и MediaRemote.
3. **Многомониторность** — панель только на экране с вырезом или следует за активным.
4. **Цвет корпуса** — подтвердить переход на чистый чёрный на экранах с вырезом (§3.5).
5. **Минимальная ОС** — 15.0 сразу (перевод в базовой поставке) или 14.0 с модулем-опцией.
