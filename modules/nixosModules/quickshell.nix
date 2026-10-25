{ self, inputs, ... }: {
  flake.nixosModules.quickshell = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.quickshell;
    in {
      options.carbon.quickshell = {
        package = lib.mkPackageOption pkgs "quickshell" { };
        config = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "bar";
          description = ''
            Name of the config to run, i.e. `/etc/xdg/quickshell/<name>/shell.qml`.
            When null, quickshell runs `/etc/xdg/quickshell/shell.qml` or
            `~/.config/quickshell/shell.qml`.
          '';
        };
      };

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
            ExecStart = lib.escapeShellArgs (
              [ (lib.getExe cfg.package) ] ++ lib.optionals (cfg.config != null) [ "--config" cfg.config ]
            );
            Restart = "always";
            RestartSec = 1;
          };
        };

        # Hot reload doesn't see /etc/static flip on a switch; kill it and let the service restart it.
        system.activationScripts.reloadQuickshell = {
          deps = [ "etc" ];
          text = ''
            ${pkgs.procps}/bin/pkill -x '\.?quickshell(-wra)?' || true
          '';
        };
      };
    };
}
