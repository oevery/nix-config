cask "ishellpro" do
  arch arm: "1", intel: "2"

  version :latest
  sha256 :no_check

  url "https://api.ishell.cc/download/#{arch}/cn",
      verified: "api.ishell.cc/"
  name "iShellPro"
  desc "SSH, SFTP, RDP, VNC, and server management client"
  homepage "https://ishell.cc/"

  app "ishellpro.app"
end
