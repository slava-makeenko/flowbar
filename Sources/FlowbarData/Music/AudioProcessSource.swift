import AppKit
import CoreAudio
import Foundation

/// Приложение, которое прямо сейчас выводит звук.
///
/// Публичный API CoreAudio, доступный с macOS 14.4. Отвечает на вопрос «кто играет» —
/// единственный вопрос про чужое воспроизведение, на который система ещё отвечает
/// без приватных фреймворков. ADR-0010.
public struct AudioProcessSource: Sendable {

  /// Создаёт источник.
  public init() {}

  /// Идентификатор бандла приложения, выводящего звук.
  /// - Returns: идентификатор или `nil`, если звука нет.
  public func playingBundleIdentifier() -> String? {
    for process in Self.audioProcesses() where Self.isRunningOutput(process) {
      if let bundle = Self.bundleIdentifier(of: process), !bundle.isEmpty {
        return bundle
      }
    }
    return nil
  }

  /// Отображаемое имя приложения, выводящего звук.
  /// - Returns: имя или `nil`, если звука нет.
  public func playingApplicationName() -> String? {
    guard let bundle = playingBundleIdentifier() else { return nil }
    return Self.displayName(for: bundle)
  }

  /// Имя приложения по идентификатору бандла.
  ///
  /// Звук браузера выводит вспомогательный процесс — `com.apple.WebKit.GPU` у Safari,
  /// `…Helper` у Chrome. Пользователю нужно имя самого браузера, поэтому сначала ищем
  /// среди запущенных приложений, а лишь потом показываем сырой идентификатор.
  static func displayName(for bundleIdentifier: String) -> String {
    if let known = knownHosts[bundleIdentifier] { return known }
    let running = NSWorkspace.shared.runningApplications
    if let application = running.first(where: { $0.bundleIdentifier == bundleIdentifier }),
      let name = application.localizedName
    {
      return name
    }
    return bundleIdentifier
  }

  /// Идентификатор браузера, которому принадлежит звуковой процесс.
  /// - Parameter bundleIdentifier: идентификатор процесса, выводящего звук.
  /// - Returns: идентификатор браузера или `nil`.
  public static func browserOwning(_ bundleIdentifier: String) -> String? {
    browserHosts[bundleIdentifier]
  }

  /// Вспомогательные процессы браузеров, выводящие звук за них.
  private static let browserHosts: [String: String] = [
    "com.apple.WebKit.GPU": "com.apple.Safari",
    "com.google.Chrome.helper": "com.google.Chrome",
    "com.google.Chrome.helper.Renderer": "com.google.Chrome",
  ]

  private static let knownHosts: [String: String] = [
    "com.apple.WebKit.GPU": "Safari",
    "com.google.Chrome.helper": "Chrome",
    "com.google.Chrome.helper.Renderer": "Chrome",
  ]

  // MARK: - CoreAudio

  private static func audioProcesses() -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size = UInt32(0)
    guard
      AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr
    else { return [] }

    var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects) == noErr
    else { return [] }
    return objects
  }

  private static func isRunningOutput(_ process: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyIsRunningOutput,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var running = UInt32(0)
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &running) == noErr else {
      return false
    }
    return running != 0
  }

  private static func bundleIdentifier(of process: AudioObjectID) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyBundleID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    guard AudioObjectGetPropertyData(process, &address, 0, nil, &size, &value) == noErr else {
      return nil
    }
    return value as String
  }
}
