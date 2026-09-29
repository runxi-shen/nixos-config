cask "openwhispr" do
  version "1.10.2"
  sha256 "9a0ebf207a96ca7d039d45299a80d0da1172a6aebed52fd63a65e09cff44463d"

  url "https://github.com/OpenWhispr/openwhispr/releases/download/v#{version}/OpenWhispr-#{version}-arm64.dmg"
  name "OpenWhispr"
  desc "Privacy-first voice dictation, meeting transcription, and notes"
  homepage "https://openwhispr.com/"

  auto_updates true
  depends_on arch: :arm64

  # Homebrew's normal `app` artifact loses the extended-attribute signatures
  # on several bundled resources. Preserve them so `codesign --deep --strict`
  # remains valid after copying the notarized app out of the DMG.
  installer script: {
    executable: "/usr/bin/ditto",
    args:       [
      "--rsrc",
      "--extattr",
      "#{staged_path}/OpenWhispr.app",
      "/Applications/OpenWhispr.app",
    ],
  }

  uninstall quit:   "com.gizmolabs.openwhispr",
            delete: "/Applications/OpenWhispr.app"

  zap trash: [
    "~/Library/Application Support/OpenWhispr",
    "~/Library/Caches/com.gizmolabs.openwhispr",
    "~/Library/Preferences/com.gizmolabs.openwhispr.plist",
    "~/Library/Saved Application State/com.gizmolabs.openwhispr.savedState",
    "~/.cache/openwhispr",
  ]
end
