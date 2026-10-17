# SwitchSound native

Accessible native desktop implementations with no external audio bridge.

- `windows/`: WPF/.NET 8, Windows UI Automation, native Core Audio COM.
- `macos/`: SwiftUI/AppKit, VoiceOver semantics, native CoreAudio.

The Windows release is built self-contained so testers do not need .NET installed. Build with `windows/build.ps1`.

The macOS app must be compiled on macOS with Xcode Command Line Tools. Run `macos/build-app.sh`; the result is `macos/dist/SwitchSound.app`. macOS requires Accessibility permission for the global Control+Backslash listener.
