import AppKit
import FlowbarDomain
import Foundation

/// Название вкладки браузера, которая сейчас выводит звук.
///
/// Метаданных трека браузер не отдаёт никому, кроме системного виджета, но название
/// вкладки — это ровно то, что пользователь и читает: «Frostpunk 2 с Майкером».
///
/// **Оговорка честности:** берётся вкладка активного окна, а звучать может другая.
/// Отличить их публичными средствами нельзя: признака «эта вкладка со звуком» в словаре
/// ни Safari, ни Chrome нет.
@MainActor
public struct BrowserNowPlayingAdapter: NowPlayingReading {

  private static let scripts: [String: String] = [
    "com.apple.Safari": "tell application \"Safari\" to return name of current tab of front window",
    "com.google.Chrome":
      "tell application \"Google Chrome\" to return title of active tab of front window",
  ]

  private let audio: AudioProcessSource

  /// Создаёт адаптер.
  /// - Parameter audio: источник сведений о том, кто выводит звук.
  public init(audio: AudioProcessSource = AudioProcessSource()) {
    self.audio = audio
  }

  /// Что звучит в браузере.
  /// - Returns: название вкладки, имя браузера или `.silence`.
  public func current() async -> NowPlaying {
    guard let bundle = audio.playingBundleIdentifier(),
      let browser = AudioProcessSource.browserOwning(bundle)
    else { return .silence }

    let name = AudioProcessSource.displayName(for: bundle)
    guard let title = tabTitle(browser: browser), !title.isEmpty else {
      return .application(name: name)
    }
    return .track(Track(title: title, artist: "", source: name))
  }

  private func tabTitle(browser: String) -> String? {
    guard let source = Self.scripts[browser], let script = NSAppleScript(source: source) else {
      return nil
    }
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    guard error == nil else { return nil }
    return result.stringValue
  }
}

/// Приложение, выводящее звук, когда о треке ничего не известно.
///
/// Последний в цепочке: отвечает всегда, когда звук вообще идёт.
@MainActor
public struct AudioProcessNowPlayingAdapter: NowPlayingReading {

  private let audio: AudioProcessSource

  /// Создаёт адаптер.
  /// - Parameter audio: источник сведений о том, кто выводит звук.
  public init(audio: AudioProcessSource = AudioProcessSource()) {
    self.audio = audio
  }

  /// Имя приложения, выводящего звук.
  /// - Returns: `.application` или `.silence`.
  public func current() async -> NowPlaying {
    guard let name = audio.playingApplicationName() else { return .silence }
    return .application(name: name)
  }
}
