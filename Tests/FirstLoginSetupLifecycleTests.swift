import AppKit

// Use the real application lifecycle and guide with no TIS registration or
// System Settings side effects. This runs in a disposable test bundle/home.
@MainActor enum Installation {
    static var registered = false
    static func hasEnabledSource() -> Bool { false }
    static func register() throws {
        precondition(NSApp.isRunning, "The guide must wait for application launch")
        registered = true
    }
}

@main struct FirstLoginSetupLifecycleTests {
    @MainActor static func main() {
        let defaults = UserDefaults.standard
        let expectSkipped = CommandLine.arguments.contains("--expect-completed")
        if expectSkipped {
            precondition(defaults.bool(forKey: FirstLoginSetup.completedKey), "First run must persist completion")
        } else {
            // CFPreferences may reuse its daemon cache across temporary homes.
            // Reset only this dedicated test bundle's state before the first run.
            defaults.removeObject(forKey: FirstLoginSetup.completedKey)
            defaults.synchronize()
            precondition(!defaults.bool(forKey: FirstLoginSetup.completedKey))
        }
        let deadline = Date().addingTimeInterval(10)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated {
                if Date() > deadline { fatalError("Setup guide did not appear") }
                guard let window = NSApp.modalWindow, window.isVisible else { return }
                precondition(!expectSkipped, "Completed setup must not show a second guide")
                precondition(NSApp.isRunning && Installation.registered)
                print("PASS real AppKit launch completes before guide presentation")
                NSApp.stopModal(withCode: .alertSecondButtonReturn)
            }
        }
        RunLoop.main.add(timer, forMode: .modalPanel)
        FirstLoginSetup.runIfRequested(openSettings: {
            precondition(NSApp.isRunning && Installation.registered)
            return true
        })
        fatalError("Helper should exit after the guide or completed-state check")
    }
}
