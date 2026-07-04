{ pkgs, ... }:
let
  demoApiKey = "demo";
  apiKeyFile = toString (pkgs.writeText "hostmap-api-key.txt" demoApiKey);
  homeDir = "/var/lib/ci";
  repoDir = "${homeDir}/hostmap-demo.git";
  postReceiveHook = pkgs.writeShellScript "post-receive" (
    builtins.readFile ./post-receive-hook.sh
  );

in
{
  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    nix
  ];
  users.groups.ci = { };

  users.users.ci = {
    isNormalUser = true;
    home = homeDir;
    createHome = true;
    extraGroups = [ "wheel" ];
	openssh.authorizedKeys.keyFiles = [
	  ../test-key.pub
	];
  };

  systemd.services.init-ci-repo = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "ci";
      Group = "ci";
    };

    script = ''
      	  set -euo pipefail

      	  mkdir -p ${homeDir}

      	  if [ ! -f ${repoDir}/HEAD ]; then
      	    rm -rf ${repoDir}
      		mkdir -p ${repoDir}
      		${pkgs.git}/bin/git init --bare ${repoDir}
      	  fi
      	  mkdir -p ${repoDir}/hooks
      	  install -m 0755 ${postReceiveHook} ${repoDir}/hooks/post-receive
    '';
  };
}
