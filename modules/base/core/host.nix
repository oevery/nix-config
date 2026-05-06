{
  host,
  lib,
  pkgs,
  ...
}:

let
  homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${host.username}" else "/home/${host.username}";
  localGitConfigDir = "${homeDirectory}/.config/git";
  localGitConfigPath = "~/.config/git/local.gitconfig";
  workGitConfigPath = "~/.config/git/work.gitconfig";
  workGitDirPattern = "gitdir:~/Developer/work/";
in
{
  home.username = host.username;
  home.homeDirectory = homeDirectory;

  programs.git = {
    includes = [
      {
        path = localGitConfigPath;
      }
    ];

    settings = {
      user = {
        email = host.email;
        name = host.gitName;
      };
    };

    signing = {
      key = host.gpgKey or null;
      signByDefault = (host.gpgKey or null) != null;
    };
  };

  home.activation.ensureLocalGitIncludes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${localGitConfigDir}"
        chmod 700 "${localGitConfigDir}"

        if [ ! -e "${localGitConfigDir}/local.gitconfig" ]; then
          cat > "${localGitConfigDir}/local.gitconfig" <<EOF
    # Local Git include rules.
    # Add more includeIf/include entries here when needed.

    [includeIf "${workGitDirPattern}"]
    	path = ${workGitConfigPath}
    EOF
          chmod 600 "${localGitConfigDir}/local.gitconfig"
        fi

        if [ ! -e "${localGitConfigDir}/work.gitconfig" ]; then
          cat > "${localGitConfigDir}/work.gitconfig" <<'EOF'
    # [user]
    #   name = Your Work Name
    #   email = you@company.com
    #   signingkey = WORK_KEY_ID
    #
    # [commit]
    #   gpgsign = true
    #
    # [core]
    #   sshCommand = ssh -i ~/.ssh/id_ed25519_work
    #
    # [url "git@github.com:"]
    #   insteadOf = https://github.com/
    EOF
          chmod 600 "${localGitConfigDir}/work.gitconfig"
        fi
  '';

}
