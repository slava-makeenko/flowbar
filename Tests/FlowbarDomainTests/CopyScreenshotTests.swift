import FlowbarDomain
import FlowbarTestSupport
import Foundation
import Testing

private let url = URL(fileURLWithPath: "/Desktop/shot.png")
private let raster = Data([0x89, 0x50, 0x4E, 0x47])

private let screenshot = Screenshot(
  id: url,
  name: "shot.png",
  pixelSize: PixelSize(width: 1244, height: 806),
  byteSize: 2048,
  createdAt: Date(timeIntervalSince1970: 1_700_000_000)
)

@Test("Снимок кладётся в пастборд ссылкой и растром сразу")
func writesBothRepresentations() async {
  let pasteboard = FakePasteboard()
  let copy = CopyScreenshot(files: FakeFileReader(files: [url: raster]), pasteboard: pasteboard)

  let copied = await copy(screenshot)

  #expect(copied)
  #expect(await pasteboard.writes == [.file(url: url, image: raster)])
}

@Test("Без растра в пастборд не пишется ничего")
func writesNothingWithoutRaster() async {
  let pasteboard = FakePasteboard()
  let copy = CopyScreenshot(files: FakeFileReader(), pasteboard: pasteboard)

  let copied = await copy(screenshot)

  #expect(copied == false)
  #expect(await pasteboard.writes.isEmpty)
}
