cask "armkeykey" do
  version "0.8.0,15"
  sha256 "4e21ac7859fe62ee4f50b430b209656dde159d70dff21bf7f8712ad0aedb50aa"

  url "https://github.com/jr-everstar/ArmKeyKey/releases/download/v#{version.csv.first}-build#{version.csv.second}/ArmKeyKey-#{version.csv.first}-build#{version.csv.second}-mac-arm64.pkg"
  name "ArmKeyKey"
  desc "Cangjie, Quick and Cantonese input method for Apple Silicon"
  homepage "https://jr-everstar.github.io/ArmKeyKey/"

  livecheck do
    url :url
    regex(/^v(\d+(?:\.\d+)+)-build(\d+)$/i)
    strategy :github_releases do |json, regex|
      json.filter_map do |release|
        next if release["draft"] || release["prerelease"]

        match = release["tag_name"]&.match(regex)
        next if match.blank?

        "#{match[1]},#{match[2]}"
      end
    end
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  pkg "ArmKeyKey-#{version.csv.first}-build#{version.csv.second}-mac-arm64.pkg"

  uninstall pkgutil: "everstar.armkeykey.mac.pkg"

  caveats do
    logout
    <<~EOS
      Save your work, switch to another input source and quit ArmKeyKey in all
      logged-in accounts before installing, upgrading or uninstalling.
      Move any personal copy out of ~/Library/Input Methods first; keep your
      learning data. Installation requires administrator authorization.
      After installation, log out and back in manually, then add ArmKeyKey
      under System Settings > Keyboard > Text Input > Chinese, Traditional.
      Before uninstalling, also remove ArmKeyKey from your input sources.
    EOS
  end
end
