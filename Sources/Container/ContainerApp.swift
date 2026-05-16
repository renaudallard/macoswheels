#if canImport(SwiftUI) && canImport(SystemExtensions)

import SwiftUI
import SystemExtensions

@main
struct MacoswheelsContainerApp: App {
    var body: some Scene {
        WindowGroup("macoswheels") {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var status = "DEXT not yet activated"
    var body: some View {
        VStack(spacing: 16) {
            Text("macoswheels").font(.title)
            Text(status).foregroundStyle(.secondary)
            Button("Activate DEXT") { activate() }
            Button("Deactivate DEXT") { deactivate() }
        }.padding(40).frame(width: 360, height: 220)
    }

    private func activate() {
        let req = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: "it.allard.macoswheels.dext",
            queue: .main)
        req.delegate = ExtensionDelegate.shared
        OSSystemExtensionManager.shared.submitRequest(req)
        status = "activation submitted"
    }

    private func deactivate() {
        let req = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: "it.allard.macoswheels.dext",
            queue: .main)
        req.delegate = ExtensionDelegate.shared
        OSSystemExtensionManager.shared.submitRequest(req)
        status = "deactivation submitted"
    }
}

final class ExtensionDelegate: NSObject, OSSystemExtensionRequestDelegate {
    static let shared = ExtensionDelegate()
    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {}
    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result) {}
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {}
}

#endif
