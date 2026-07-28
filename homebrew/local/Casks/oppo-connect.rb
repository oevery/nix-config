cask "oppo-connect" do
  require "digest"
  require "json"
  require "net/http"
  require "uri"

  platform = Hardware::CPU.arm? ? "macos-arm" : "macos-x64"
  timestamp = Time.now.to_i.to_s
  params = "platform=#{platform}&serverName=connect.oppo.com"
  signing_salt = "c9412a3fc35f465ca5abe7001bc48d20"
  signature = Digest::SHA256.hexdigest("#{params}#{timestamp}#{signing_salt}")

  metadata_uri = URI("https://connect.oppo.com/api/v2/updatePackage/queryUrl?#{params}")
  metadata_request = Net::HTTP::Get.new(metadata_uri)
  metadata_request["appId"] = "pc-web"
  metadata_request["sign"] = signature
  metadata_request["ts"] = timestamp
  metadata_http = Net::HTTP.new(metadata_uri.hostname, metadata_uri.port)
  metadata_http.use_ssl = true
  metadata_http.open_timeout = 10
  metadata_http.read_timeout = 20
  metadata_response = metadata_http.request(metadata_request)
  unless metadata_response.is_a?(Net::HTTPSuccess)
    raise "OPPO Connect metadata request failed: HTTP #{metadata_response.code}"
  end

  metadata_payload = JSON.parse(metadata_response.body)
  unless metadata_payload["code"] == 200
    raise "OPPO Connect metadata request failed: #{metadata_payload["message"]}"
  end

  metadata = metadata_payload.fetch("data")

  version metadata.fetch("version")
  sha256 metadata.fetch("sha256")

  url metadata.fetch("downloadUrl"),
      verified: "pc-assistant-cn.allawnfs.com/",
      referer: "https://connect.oppo.com/"
  name "OPPO Connect"
  name "OPPO 互联"
  desc "Cross-device file sharing, screen collaboration, and content synchronization"
  homepage "https://connect.oppo.com/zh-CN#/pc"

  app "O+Connect.app"
end
