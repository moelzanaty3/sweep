# Canonical source for the Homebrew cask. Copy to Casks/sweep.rb in the
# moelzanaty3/homebrew-tap repository when cutting a release.
cask "sweep" do
  version "1.0.0"
  sha256 "411bd336526bb1a47e5395885f5c35257b194f920a4a80765ade304b2591baf4"

  url "https://github.com/moelzanaty3/sweep/releases/download/v#{version}/Sweep-#{version}.dmg"
  name "Sweep"
  desc "Disk hygiene for developers"
  homepage "https://github.com/moelzanaty3/sweep"

  depends_on macos: ">= :sonoma"

  app "Sweep.app"

  # Until the app is notarized, installing needs --no-quarantine.
  caveats <<~CAVEATS
    Sweep is not yet notarized by Apple. If macOS refuses to open it, either
    reinstall with:

      brew install --cask --no-quarantine sweep

    or right-click the app and choose Open the first time.
  CAVEATS

  zap trash: [
    "~/Library/Preferences/com.elzanaty.sweep.plist",
    "~/Library/Caches/com.elzanaty.sweep",
    "~/Library/Saved Application State/com.elzanaty.sweep.savedState",
  ]
end
