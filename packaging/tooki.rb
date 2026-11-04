# Homebrew cask, published in the tahsinature/homebrew-tap repository.
cask "tooki" do
  version :latest
  sha256 :no_check

  url "https://github.com/tahsinature/tooki/releases/latest/download/Tooki.dmg"
  name "Tooki"
  desc "Hyper Key, snippets, clipboard history, menu bar organizer and keep awake"
  homepage "https://github.com/tahsinature/tooki"

  depends_on macos: ">= :sonoma"

  app "Tooki.app"

  # Tooki is not notarized, so remove the quarantine flag that would block the first launch.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/Tooki.app"]
  end

  uninstall quit: "com.mohammadtahsin.tooki"
end
