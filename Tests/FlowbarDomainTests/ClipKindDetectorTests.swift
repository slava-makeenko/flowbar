import FlowbarDomain
import Foundation
import Testing

/// Один вход таблицы «содержимое → вид».
struct KindSample: Sendable, CustomStringConvertible {

  let description: String
  let item: PasteboardItem
  let expected: ClipKind

  static let notes = SourceApp(name: "Notes", bundleIdentifier: "com.apple.Notes")
  static let terminal = SourceApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal")
  static let finder = SourceApp(name: "Finder", bundleIdentifier: "com.apple.finder")

  static let all: [KindSample] = [
    KindSample(
      description: "обычный текст",
      item: PasteboardItem(text: "Собрать прототип панели", sourceApp: notes),
      expected: .text
    ),
    KindSample(
      description: "ссылка целиком",
      item: PasteboardItem(text: "https://linear.app/flowbar/issue/FB-12", sourceApp: notes),
      expected: .link
    ),
    KindSample(
      description: "код по фигурным скобкам",
      item: PasteboardItem(text: "func main() { print(1) }", sourceApp: notes),
      expected: .code
    ),
    KindSample(
      description: "растр",
      item: PasteboardItem(imageData: Data([0x89, 0x50]), sourceApp: notes),
      expected: .image
    ),
    KindSample(
      description: "цвет в hex",
      item: PasteboardItem(text: "#5E6AD2", sourceApp: notes),
      expected: .color
    ),
    KindSample(
      description: "почтовый адрес",
      item: PasteboardItem(text: "1 Infinite Loop, Cupertino, CA 95014", sourceApp: notes),
      expected: .address
    ),
    KindSample(
      description: "путь к файлу",
      item: PasteboardItem(fileURL: URL(fileURLWithPath: "/tmp/tokens.css"), sourceApp: finder),
      expected: .path
    ),
    KindSample(
      description: "хеш как значение",
      item: PasteboardItem(text: "9f2c4a8e10b7", sourceApp: terminal),
      expected: .value
    ),
    KindSample(
      description: "адрес почты",
      item: PasteboardItem(text: "slava@sensorehab.com", sourceApp: notes),
      expected: .email
    ),
  ]
}

@Test("Вид копии определяется для всех девяти видов", arguments: KindSample.all)
func detectsEveryKind(sample: KindSample) {
  let detector = ClipKindDetector()

  #expect(detector.detect(sample.item) == sample.expected, "\(sample.description)")
}

@Test("Таблица покрывает все объявленные виды")
func tableCoversEveryDeclaredKind() {
  let covered = Set(KindSample.all.map(\.expected))

  #expect(covered == Set(ClipKind.allCases))
}

@Test("Значение определяется раньше кода: хеш из терминала — не код")
func valueWinsOverCode() {
  let item = PasteboardItem(text: "9f2c4a8e10b7", sourceApp: KindSample.terminal)

  #expect(ClipKindDetector().detect(item) == .value)
}

@Test("Почта определяется раньше ссылки: детектор считает адрес ссылкой")
func emailWinsOverLink() {
  let item = PasteboardItem(text: "alex@sensorehab.com", sourceApp: KindSample.notes)

  #expect(ClipKindDetector().detect(item) == .email)
}

@Test("Путь определяется раньше остальных правил")
func pathWinsOverText() {
  let item = PasteboardItem(
    text: "https://example.com",
    fileURL: URL(fileURLWithPath: "/tmp/shot.png"),
    sourceApp: KindSample.finder
  )

  #expect(ClipKindDetector().detect(item) == .path)
}

@Test("Не сработавшая цепочка даёт текст")
func fallsBackToText() {
  let item = PasteboardItem(text: "просто фраза", sourceApp: KindSample.notes)

  #expect(ClipKindDetector().detect(item) == .text)
}
