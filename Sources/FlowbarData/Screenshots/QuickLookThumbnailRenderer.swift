import AppKit
import FlowbarDomain
import QuickLookThumbnailing

/// Превью снимков через QuickLook.
public actor QuickLookThumbnailRenderer: ThumbnailRendering {

  /// Масштаб превью: экран Retina.
  private static let scale: CGFloat = 2

  private var cache: [String: Data] = [:]

  /// Создаёт рендерер.
  public init() {}

  /// Строит превью снимка.
  ///
  /// Результат кэшируется по паре «путь + время изменения»: тот же файл после
  /// редактирования даст другой ключ, а переоткрытие панели — тот же.
  /// - Parameters:
  ///   - url: путь к файлу.
  ///   - size: желаемый размер превью в пикселях.
  /// - Returns: растр превью или `nil`, если построить не удалось.
  public func thumbnail(for url: URL, size: PixelSize) async -> Data? {
    let key = Self.cacheKey(for: url, size: size)
    if let cached = cache[key] { return cached }

    let request = QLThumbnailGenerator.Request(
      fileAt: url,
      size: CGSize(
        width: CGFloat(size.width) / Self.scale,
        height: CGFloat(size.height) / Self.scale
      ),
      scale: Self.scale,
      representationTypes: .thumbnail
    )

    guard
      let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(
        for: request
      ),
      let data = Self.png(from: representation.cgImage)
    else { return nil }

    cache[key] = data
    return data
  }

  private static func cacheKey(for url: URL, size: PixelSize) -> String {
    let modified =
      (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
      .contentModificationDate?.timeIntervalSince1970 ?? 0
    return "\(url.path)|\(modified)|\(size.width)x\(size.height)"
  }

  private static func png(from image: CGImage) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  }
}
