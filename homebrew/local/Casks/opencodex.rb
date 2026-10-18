cask "opencodex" do
  require "net/http"
  require "uri"

  # 使用官网 latest 跳转，避免匿名 GitHub API 的速率限制。
  release_uri = URI("https://github.com/lidge-jun/opencodex/releases/latest")
  request = Net::HTTP::Head.new(release_uri)
  request["User-Agent"] = "Homebrew-opencodex-cask"
  http = Net::HTTP.new(release_uri.hostname, release_uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 20
  response = http.request(request)
  unless response.is_a?(Net::HTTPRedirection)
    raise "OpenCodex release lookup failed: HTTP #{response.code}"
  end

  tag = response["location"].to_s.match(%r{\Ahttps://github\.com/lidge-jun/opencodex/releases/tag/v([0-9][0-9A-Za-z.+-]*)\z})
  raise "Unexpected OpenCodex latest release redirect" unless tag

  release_version = tag[1]
  download_url = "https://github.com/lidge-jun/opencodex/releases/download/v#{release_version}/OpenCodex-#{release_version}-macos.dmg"

  version :latest
  sha256 :no_check

  url download_url
  name "OpenCodex"
  desc "Desktop dashboard and menu bar companion for the OpenCodex proxy"
  homepage "https://opencodex.me/"

  auto_updates true
  depends_on macos: :ventura

  app "OpenCodex.app"
end
