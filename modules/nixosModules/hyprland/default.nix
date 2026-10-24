{ self, inputs, ... }: {
  flake.nixosModules.hyprland = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.hyprland;
      toLua = lib.generators.toLua { multiline = false; };
      monitorLine = m: "hl.monitor(${toLua (removeAttrs m [ "workspace" "greeter" ])})";
      workspaceLine = m:
        "hl.workspace_rule(${toLua { workspace = toString m.workspace; monitor = m.output; }})";
      monitorLines = lib.concatStringsSep "\n" (
        map monitorLine cfg.monitors
        ++ map workspaceLine (lib.filter (m: m ? workspace) cfg.monitors)
      );
    in {
      options.carbon.hyprland = {
        monitors = lib.mkOption {
          type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
          default = [ ];
          example = [{ output = "DP-1"; mode = "2560x1440@165"; position = "auto"; scale = 1; workspace = 1; }];
          description = ''
            Monitors, each passed to `hl.monitor` in hyprland.lua. The optional
            `workspace` attribute pins that workspace to the monitor, and
            `greeter = true` shows the login greeter on it (see the regreet module).
          '';
        };

        terminal = lib.mkOption {
          type = lib.types.package;
          default = pkgs.ghostty;
          defaultText = lib.literalExpression "pkgs.ghostty";
          description = "Terminal opened with Mod+Q.";
        };

        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Lua appended to hyprland.lua; later `hl.config` calls override earlier ones.";
        };
      };

      config = {
        programs.hyprland = {
          enable = true;
          withUWSM = false;
        };
        programs.hyprlock.enable = true;
        security.pam.services.hyprlock.enableGnomeKeyring = config.services.gnome.gnome-keyring.enable;

        services.xserver.enable = true;

        environment.systemPackages = with pkgs; [
          cfg.terminal
          hyprpaper
          hyprpicker
          hyprshot
          wl-clipboard
        ];

        environment.etc."hypr/hyprland.lua".text =
          monitorLines + "\n\n"
          + "local terminal    = \"${cfg.terminal.meta.mainProgram}\"\n"
          + builtins.readFile ./hyprland.lua
          + lib.optionalString (cfg.extraConfig != "") ("\n" + cfg.extraConfig);
        environment.etc."hypr/hyprlock.conf".source = ./hyprlock.conf;
        environment.etc."hypr/hyprpaper.conf".source = ./hyprpaper.conf;

        environment.sessionVariables.HYPRLAND_CONFIG = "/etc/hypr/hyprland.lua";

        # xdg-desktop-portal >= 1.22 refuses to start unless
        # graphical-session.target is active, and Hyprland without UWSM never
        # activates it. That target is RefuseManualStart, so bind it to a
        # session target Hyprland can start itself (see the hyprland.start
        # handler in hyprland.lua). Without this, screen sharing has no ScreenCast portal.
        systemd.user.targets.hyprland-session = {
          description = "Hyprland compositor session";
          documentation = [ "man:systemd.special(7)" ];
          bindsTo = [ "graphical-session.target" ];
          wants = [ "graphical-session-pre.target" ];
          after = [ "graphical-session-pre.target" ];
        };
      };
    };
}
