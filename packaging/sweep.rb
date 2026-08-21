# Canonical source for the Homebrew cask. Copy to Casks/sweep.rb in the
# moelzanaty3/homebrew-tap repository when cutting a release.
cask "sweep" do
  version "1.0.1"
  sha256 "b1856e2bcfc9595d99b07b1b4d19234498fac2a3d878dcdb36309d91a8d54fa8"

  url "https://github.com/moelzanaty3/sweep/releases/download/v#{version}/Sweep-#{version}.dmg"
  name "Sweep"
  desc "Disk hygiene for developers"
  homepage "https://github.com/moelzanaty3/sweep"

  depends_on macos: :sonoma

  app "Sweep.app"

  # Homebrew 6 removed --no-quarantine, so the cask cannot opt out and the
  # download arrives quarantined. Until the app is notarized, clearing the
  # attribute by hand is the only reliable route.
  caveats <<~CAVEATS
    Sweep is not notarized by Apple yet, so macOS will refuse to open it.

    To allow it:

      xattr -dr com.apple.quarantine /Applications/Sweep.app

    Or open System Settings > Privacy & Security and click "Open Anyway"
    after the first blocked launch.
  CAVEATS

  zap trash: [
    "~/Library/Preferences/com.elzanaty.sweep.plist",
    "~/Library/Caches/com.elzanaty.sweep",
    "~/Library/Saved Application State/com.elzanaty.sweep.savedState",
  ]
end
