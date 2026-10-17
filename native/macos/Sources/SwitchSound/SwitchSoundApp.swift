import AppKit
import SwiftUI

extension Notification.Name {
    static let switchSoundCycleOutput = Notification.Name("SwitchSoundCycleOutput")
}

@MainActor
final class AppModel: ObservableObject {
    @Published var outputs: [OutputDevice] = []
    @Published var selectedUID = ""
    @Published var status = "Loading audio outputs"
    private let audio = CoreAudioService()

    func refresh() {
        do {
            outputs = try audio.outputs()
            let current = outputs.first(where: \.isDefault)
            if selectedUID.isEmpty || !outputs.contains(where: { $0.uid == selectedUID }) {
                selectedUID = current?.uid ?? outputs.first?.uid ?? ""
            }
            status = "Current output: \(current?.name ?? "Unknown")"
        } catch {
            status = "Could not read audio outputs: \(error.localizedDescription)"
        }
    }

    func useSelectedOutput() {
        guard !selectedUID.isEmpty else {
            status = "Choose an audio output."
            return
        }
        setOutput(uid: selectedUID)
    }

    func cycleOutput() {
        refresh()
        guard !outputs.isEmpty else { return }
        let currentIndex = outputs.firstIndex(where: \.isDefault) ?? -1
        let nextIndex = (currentIndex + 1) % outputs.count
        selectedUID = outputs[nextIndex].uid
        setOutput(uid: selectedUID)
    }

    private func setOutput(uid: String) {
        do {
            try audio.setDefault(uid: uid)
            refresh()
        } catch {
            status = "Could not switch output: \(error.localizedDescription)"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Text("SwitchSound").font(.title).accessibilityAddTraits(.isHeader)
            Picker("Audio output", selection: $model.selectedUID) {
                ForEach(model.outputs) { Text($0.name).tag($0.uid) }
            }
            .accessibilityHint("Choose the system audio output by its friendly name")

            Button("Use selected output") { model.useSelectedOutput() }
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityHint("Makes the selected device the default audio output")

            HStack {
                Text(model.status).accessibilityLabel(model.status)
                Spacer()
                Button("Refresh") { model.refresh() }
            }
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 230)
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .switchSoundCycleOutput)) { _ in
            model.cycleOutput()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let handler: (NSEvent) -> Void = { event in
            guard event.modifierFlags.contains(.control),
                  event.charactersIgnoringModifiers == "\\" else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .switchSoundCycleOutput, object: nil)
            }
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return event
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct SwitchSoundApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("SwitchSound") { MainView(model: model) }
        MenuBarExtra("SwitchSound", systemImage: "headphones") {
            Button("Switch to next output") { model.cycleOutput() }
            Button("Show SwitchSound") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows
                    .first(where: { $0.title == "SwitchSound" })?
                    .makeKeyAndOrderFront(nil)
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
