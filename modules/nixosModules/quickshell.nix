{ self, inputs, ... }: {
  flake.nixosModules.quickshell = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.quickshell;
    in {
      options.carbon.quickshell.package = lib.mkPackageOption pkgs "quickshell" { };

      config = {
        environment.systemPackages = [ cfg.package ];

        systemd.user.services.quickshell = {
          description = "Quickshell";
          documentation = [ "https://quickshell.org/docs/" ];
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          requisite = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];
          # Inherit the session PATH so Process and exec commands resolve.
          environment.PATH = lib.mkForce null;
          serviceConfig = {
            ExecStart = lib.getExe cfg.package;
            Restart = "always";
            RestartSec = 1;
          };
        };

        # Hot reload misses config changes from a switch, so kill it and let the service restart it.
        system.activationScripts.reloadQuickshell = {
          deps = [ "etc" ];
          text = ''
            # Process names are cut to 15 characters, hence "-wra".
            ${pkgs.procps}/bin/pkill -x '\.?quickshell(-wra)?' || true
          '';
        };
      };
    };
}
