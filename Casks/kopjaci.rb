cask "kopjaci" do
  version "0.1"
  sha256 "dfebabd554b13426d69ed1f8b7e0e28a742a0eb443e584e964b95a1b957bb244"

  url "https://github.com/ergis-m/kopjaci/releases/download/v#{version}/Kopjaci-#{version}.zip"
  name "Kopjaci"
  desc "Clipboard history with hold-to-pick paste"
  homepage "https://github.com/ergis-m/kopjaci"

  depends_on macos: :tahoe

  app "Kopjaci.app"

  zap trash: [
    "~/Library/Application Support/Kopjaci",
    "~/Library/Preferences/dev.ergis.kopjaci.plist",
  ]

  caveats <<~EOS
    Kopjaci is not notarized. If macOS refuses to open it, allow it once in
    System Settings > Privacy & Security ("Open Anyway"), or reinstall with
      brew reinstall --cask --no-quarantine kopjaci
    It also needs Accessibility permission, which it asks for on first use.
  EOS
end
