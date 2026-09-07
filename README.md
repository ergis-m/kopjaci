# Kopjaci

Clipboard history for macOS with hold-to-pick paste. Menu bar only, no Dock icon, no dependencies.

Hold **⌘⇧** and tap **V**: a panel opens at your cursor with your recent copies. Keep tapping V (or use ↑/↓, or point with the mouse) to move the selection, let go to paste. **Esc** cancels, **⌫** removes the selected item.

Captures text, file paths and images (with source app, resolution and size). Items marked as concealed by password managers are never stored.

Requires macOS 26 and Accessibility permission (asked for on first use; it's needed to detect the key release and send the paste).

## Install

### Homebrew

```sh
brew trust --tap https://github.com/ergis-m/kopjaci   # Homebrew 6+, taps outside homebrew/* must be trusted by URL
brew tap ergis-m/kopjaci https://github.com/ergis-m/kopjaci
brew install --cask kopjaci
```

The app isn't notarized, so macOS blocks the first launch. Either allow it once in **System Settings > Privacy & Security > Open Anyway**, or install without the quarantine flag:

```sh
brew install --cask --no-quarantine kopjaci
```

### Download

Grab `Kopjaci-<version>.zip` from the [latest release](https://github.com/ergis-m/kopjaci/releases/latest), unzip, move `Kopjaci.app` to Applications. On first launch use **Open Anyway** in System Settings > Privacy & Security.

### From source

Needs Xcode 26.

```sh
git clone https://github.com/ergis-m/kopjaci && cd kopjaci
make run
```

## Release

```sh
make release          # builds, zips to build/, updates Casks/kopjaci.rb
gh release create v0.1 build/Kopjaci-0.1.zip --title v0.1
git commit -am "release 0.1"
```

Bump `CFBundleShortVersionString` in `Info.plist` first.
