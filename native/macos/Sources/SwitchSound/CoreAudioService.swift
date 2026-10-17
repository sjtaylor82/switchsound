import AudioToolbox
import CoreAudio
import Foundation

struct OutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isDefault: Bool
}

enum AudioServiceError: LocalizedError {
    case osStatus(OSStatus, String)
    case missingDevice(String)

    var errorDescription: String? {
        switch self {
        case let .osStatus(status, operation): return "\(operation) failed with status \(status)."
        case let .missingDevice(uid): return "The selected audio output is unavailable: \(uid)"
        }
    }
}

final class CoreAudioService {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)

    func outputs() throws -> [OutputDevice] {
        let defaultID = try deviceID(
            object: systemObject,
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        )
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size), "Reading audio device list")
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        try check(AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids), "Reading audio devices")

        return try ids.compactMap { id in
            var streamsAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamsSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamsAddress, 0, nil, &streamsSize) == noErr,
                  streamsSize > 0 else { return nil }
            return OutputDevice(
                id: id,
                uid: try string(object: id, selector: kAudioDevicePropertyDeviceUID),
                name: try string(object: id, selector: kAudioObjectPropertyName),
                isDefault: id == defaultID
            )
        }
    }

    func setDefault(uid: String) throws {
        guard let device = try outputs().first(where: { $0.uid == uid }) else {
            throw AudioServiceError.missingDevice(uid)
        }
        try set(device.id, selector: kAudioHardwarePropertyDefaultOutputDevice)
        try set(device.id, selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
    }

    private func deviceID(object: AudioObjectID, selector: AudioObjectPropertySelector,
                          scope: AudioObjectPropertyScope) throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value), "Reading audio property")
        return value
    }

    private func string(object: AudioObjectID, selector: AudioObjectPropertySelector) throws -> String {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value), "Reading audio device name")
        return value as String
    }

    private func set(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) throws {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var mutableID = id
        try check(AudioObjectSetPropertyData(systemObject, &address, 0, nil,
                                             UInt32(MemoryLayout<AudioDeviceID>.size), &mutableID),
                  "Changing default audio output")
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        if status != noErr { throw AudioServiceError.osStatus(status, operation) }
    }
}
