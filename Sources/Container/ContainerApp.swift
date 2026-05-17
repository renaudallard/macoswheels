#if canImport(SwiftUI) && canImport(SystemExtensions)

import SwiftUI
import SystemExtensions

@main
struct MacoswheelsContainerApp: App {
    var body: some Scene {
        WindowGroup("macoswheels") {
            ContentView()
                .frame(minWidth: 520, minHeight: 360)
        }
    }
}

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        TabView {
            DEXTPanel(model: model)
                .tabItem { Label("Driver", systemImage: "puzzlepiece.extension") }
            ConfigPanel(model: model)
                .tabItem { Label("Wheel", image: "wheel") }
        }
        .padding(20)
    }
}

final class AppModel: ObservableObject {
    @Published var status: String = "Driver not yet activated"
    @Published var rotation: Double = 900
    @Published var autocenter: Double = 0
    @Published var gain: Double = 75
    @Published var lastError: String?

    func activate() {
        let req = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: "it.allard.macoswheels.dext",
            queue: .main)
        req.delegate = ExtensionDelegate.shared
        OSSystemExtensionManager.shared.submitRequest(req)
        status = "Activation submitted; approve in System Settings if prompted"
    }

    func deactivate() {
        let req = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: "it.allard.macoswheels.dext",
            queue: .main)
        req.delegate = ExtensionDelegate.shared
        OSSystemExtensionManager.shared.submitRequest(req)
        status = "Deactivation submitted"
    }

    func apply() {
        lastError = nil
        let cli = "/usr/local/bin/macoswheels"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = [
            "range", String(UInt16(rotation)),
            "autocenter", String(UInt8(autocenter)),
            "gain", String(UInt8(gain)),
        ]
        do {
            try process.run()
            process.waitUntilExit()
            status = "Applied at \(Date().formatted(.dateTime.hour().minute().second()))"
        } catch {
            lastError = "Could not run \(cli): \(error.localizedDescription)"
        }
    }

    func installLaunchAgent() {
        guard let src = Bundle.main.url(forResource: "it.allard.macoswheels.restore",
                                        withExtension: "plist") else {
            lastError = "LaunchAgent plist not in bundle"
            return
        }
        let dest = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/it.allard.macoswheels.restore.plist")
        do {
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
            status = "LaunchAgent installed at \(dest.path)"
        } catch {
            lastError = "Could not install LaunchAgent: \(error.localizedDescription)"
        }
    }
}

struct DEXTPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Driver Extension").font(.title2)
            Text(model.status).foregroundStyle(.secondary)
            HStack {
                Button("Activate") { model.activate() }
                Button("Deactivate") { model.deactivate() }
                Spacer()
                Button("Install Restore LaunchAgent") { model.installLaunchAgent() }
            }
            if let err = model.lastError {
                Text(err).foregroundStyle(.red).font(.callout)
            }
            Spacer()
        }
    }
}

struct ConfigPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Wheel Configuration").font(.title2)

            VStack(alignment: .leading) {
                Text("Rotation range: \(Int(model.rotation))\u{00B0}")
                Slider(value: $model.rotation, in: 90...1080, step: 10)
            }

            VStack(alignment: .leading) {
                Text("Autocenter spring: \(Int(model.autocenter))%")
                Slider(value: $model.autocenter, in: 0...100, step: 1)
            }

            VStack(alignment: .leading) {
                Text("Global FFB gain: \(Int(model.gain))%")
                Slider(value: $model.gain, in: 0...100, step: 1)
            }

            HStack {
                Button("Apply") { model.apply() }
                Spacer()
            }
            if let err = model.lastError {
                Text(err).foregroundStyle(.red).font(.callout)
            }
            Spacer()
        }
    }
}

final class ExtensionDelegate: NSObject, OSSystemExtensionRequestDelegate {
    static let shared = ExtensionDelegate()
    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties)
                 -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {}
    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result) {}
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {}
}

#endif
