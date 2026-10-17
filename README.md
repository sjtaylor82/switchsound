# SwitchSound

An accessible audio-output switcher for Windows and macOS.

## Download

Download the Windows executable or universal macOS app from the GitHub Releases page.

## Use

- Choose an output from the single **Audio output** combo box. Only friendly device names are shown.
- Select **Use selected output** to make it the system default.
- Press **Control+Backslash** anywhere to cycle to the next available output.
- The Windows app stays available in the notification area when its window is closed or minimized.
- The macOS app stays available in the menu bar when its window is closed.

The macOS test build is ad-hoc signed. On first launch, Control-click the app and choose **Open** if Gatekeeper blocks it. macOS may also request Accessibility or Input Monitoring permission for the global shortcut.

## Build from source

- Windows: `native/windows/build.ps1`
- macOS: `native/macos/build-app.sh`

GitHub Actions builds `SwitchSound-Windows-x64.exe` and a Universal 2 `SwitchSound-macOS-universal.zip` whenever a version tag is pushed.
