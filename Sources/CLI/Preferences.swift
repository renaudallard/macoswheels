import Foundation

struct Preferences: Codable, Equatable {
    var rotationRangeDegrees: UInt16?
    var autocenterPercent: UInt8?
    var gainPercent: UInt8?
}

enum PreferencesStore {

    static var path: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Preferences/it.allard.macoswheels.plist")
    }

    static func load() -> Preferences {
        guard let data = try? Data(contentsOf: path) else { return Preferences() }
        return (try? PropertyListDecoder().decode(Preferences.self, from: data)) ?? Preferences()
    }

    static func save(_ prefs: Preferences) throws {
        let dir = path.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(prefs)
        try data.write(to: path, options: .atomic)
    }

    static func mutate(_ block: (inout Preferences) -> Void) throws {
        var p = load()
        block(&p)
        try save(p)
    }
}
