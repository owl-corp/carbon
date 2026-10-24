# Requires the hyprland module, whose monitors also lay out the greeter.
{ self, inputs, ... }: {
  flake.nixosModules.regreet = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.regreet;
      monitors = config.carbon.hyprland.monitors;
      toLua = lib.generators.toLua { multiline = false; };
      monitorLine = m: "hl.monitor(${toLua (removeAttrs m [ "workspace" "greeter" ])})";
      greeterMonitor = lib.findFirst (m: m.greeter or false) null monitors;
      greeterConfig = lib.concatStringsSep "\n" (
        map monitorLine monitors
        ++ lib.optionals (greeterMonitor != null) [
          "hl.workspace_rule(${toLua { workspace = "1"; monitor = greeterMonitor.output; }})"
          "hl.window_rule(${toLua { name = "greeter"; match.class = "apps.regreet"; workspace = "1"; }})"
        ]
        ++ [
          "hl.config(${toLua { misc = { disable_hyprland_logo = true; disable_splash_rendering = true; force_default_wallpaper = 0; disable_watchdog_warning = true; background_color = "rgb(2d112a)"; }; }})"
          ''
            hl.on("hyprland.start", function()
                hl.exec_cmd("${lib.getExe config.services.displayManager.regreet.package}; ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.exit()'")
            end)
          ''
        ]
      );
    in {
      options.carbon.regreet = {
        autoLogin = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            User to log in automatically at boot. The session starts locked by
            hyprlock, so there is no greeter-to-session handover. ReGreet is
            still used after logging out.
          '';
        };

        background = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Image shown behind the greeter.";
        };
      };

      config = {
        services.greetd.settings.initial_session = lib.mkIf (cfg.autoLogin != null) {
          user = cfg.autoLogin;
          command = "${config.programs.hyprland.package}/bin/start-hyprland -- --locked-cmd '${lib.getExe config.programs.hyprlock.package} --config /etc/hypr/hyprlock.conf'";
        };

        # Auto-login starts gnome-keyring without its components, so hyprlock's PAM unlock fails until something initialises them.
        systemd.user.services.gnome-keyring-start = lib.mkIf (cfg.autoLogin != null && config.services.gnome.gnome-keyring.enable) {
          description = "Initialise gnome-keyring components before the session is unlocked";
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${config.security.wrapperDir}/gnome-keyring-daemon --start --components=secrets";
          };
        };

        services.displayManager.regreet = {
          enable = true;
          theme = {
            package = lib.mkDefault pkgs.adw-gtk3;
            name = lib.mkDefault "adw-gtk3-dark";
          };
          cursorTheme = {
            package = lib.mkDefault pkgs.bibata-cursors;
            name = lib.mkDefault "Bibata-Modern-Classic";
          };
          settings.GTK.application_prefer_dark_theme = lib.mkDefault true;
          # ReGreet's own `background` setting leaks a file descriptor per frame until it hits the fd limit and hangs.
          extraCss = lib.mkIf (cfg.background != null) ''
            window {
              background-image: url("file://${cfg.background}");
              background-size: cover;
              background-position: center;
            }
          '';
        };
        # Run ReGreet in Hyprland rather than cage so it gets the same monitor layout as the session.
        services.greetd.settings.default_session.command = lib.mkForce
          "${pkgs.dbus}/bin/dbus-run-session ${config.programs.hyprland.package}/bin/Hyprland --config /etc/greetd/hyprland.lua";
        environment.etc."greetd/hyprland.lua".text = greeterConfig;
      };
    };
}
