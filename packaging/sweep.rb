# Canonical source for the Homebrew cask. Copy to Casks/sweep.rb in the
# moelzanaty3/homebrew-tap repository when cutting a release.
cask "sweep" do
  version "1.0.3"
  sha256 "3e464a44da678677119881c15de58a12a06ef469a8463ba0cc5ba03fe2cfb9ae"

  url "https://github.com/moelzanaty3/sweep/releases/download/v#{version}/Sweep-#{version}.dmg"
  name "Sweep"
  desc "Disk hygiene for developers"
  homepage "https://github.com/moelzanaty3/sweep"

  depends_on macos: :sonoma

  app "Sweep.app"

  # Sweep is not notarized yet, so the DMG arrives quarantined and Gatekeeper
  # refuses the first launch. Homebrew 6 removed --no-quarantine, so the cask
  # has to clear the attribute itself instead of asking the user to. Delete
  # this block once notarization is in place - Gatekeeper should do its job.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Sweep.app"]
  end

  zap trash: [
    "~/Library/Caches/com.elzanaty.sweep",
    "~/Library/Preferences/com.elzanaty.sweep.plist",
    "~/Library/Saved Application State/com.elzanaty.sweep.savedState",
  ]
end
