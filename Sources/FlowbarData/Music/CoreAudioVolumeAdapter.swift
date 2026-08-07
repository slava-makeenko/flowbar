import AudioToolbox
import CoreAudio
import FlowbarDomain
import Foundation

/// Системная громкость и устройство вывода.
///
/// Именно системная, а не громкость приложения: в макете это общесистемный ползунок.
public struct CoreAudioVolumeAdapter: SystemVolumeControlling {

  /// Создаёт адаптер.
  public init() {}

  /// Текущая громкость от 0 до 1.
  public var volume: Double {
    get async {
      guard let device = Self.defaultOutputDevice() else { return 0 }
      var address = Self.volumeAddress
      var value = Float32(0)
      var size = UInt32(MemoryLayout<Float32>.size)
      let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
      return status == noErr ? Double(value) : 0
    }
  }

  /// Устанавливает громкость.
  /// - Parameter volume: значение от 0 до 1.
  public func setVolume(_ volume: Double) async {
    guard let device = Self.defaultOutputDevice() else { return }
    var address = Self.volumeAddress
    var value = Float32(min(max(volume, 0), 1))
    let size = UInt32(MemoryLayout<Float32>.size)
    AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
  }

  /// Имя текущего устройства вывода.
  /// - Returns: имя или `nil`, если устройства нет.
  public func outputDeviceName() async -> String? {
    guard let device = Self.defaultOutputDevice() else { return nil }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioObjectPropertyName,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var name: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name)
    return status == noErr ? name as String : nil
  }

  private static var volumeAddress: AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioObjectPropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  private static func defaultOutputDevice() -> AudioObjectID? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var device = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
    return status == noErr && device != 0 ? device : nil
  }
}
