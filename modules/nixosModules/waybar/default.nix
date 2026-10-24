{ self, inputs, ... }: {
  flake.nixosModules.waybar = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.waybar;
      json = pkgs.formats.json { };
      term = cmd: "${cfg.terminal} ${cmd}";
    in {
      options.carbon.waybar = {
        terminal = lib.mkOption {
          type = lib.types.str;
          default = "ghostty -e";
          example = "kitty";
          description = "Command prefix used to open TUI tools from on-click actions.";
        };

        settings = lib.mkOption {
          type = json.type;
          default = { };
          description = ''
            Waybar config. Every shared value is a `mkDefault`, so a single
            key (including a whole list) can be overridden with a plain assignment.
          '';
        };

        style = lib.mkOption {
          type = lib.types.lines;
          description = "Waybar stylesheet; definitions are concatenated.";
        };
      };

      config = {
        carbon.waybar.settings = lib.mapAttrsRecursive (_: lib.mkDefault) {
          margin-top = 10;
          margin-bottom = 10;
          margin-left = 10;
          margin-right = 10;

          modules-left = [ "hyprland/workspaces" "mpris" ];
          modules-center = [ "privacy" "clock" ];
          modules-right = [ "bluetooth" "wireplumber" "cpu" "disk" "memory" "tray" ];

          clock = {
            format = "{:%b %d %R}";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "week";
              on-scroll = 1;
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                days = "<span color='#ecc6d9'><b>{}</b></span>";
                weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cava = {
            framerate = 60;
            autosens = 1;
            bars = 12;
            method = "pipewire";
            source = "auto";
            stereo = true;
            reverse = false;
            bar_delimiter = 0;
            monstercat = false;
            waves = false;
            noise_reduction = 0.77;
            input_delay = 2;
            format-icons = [ "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
            actions.on-click-right = "mode";
          };

          mpris = {
            player = "spotify";
            format = "{title} - {artist}";
          };

          wireplumber = {
            format = "{volume}%";
            format-muted = "Muted";
            on-click = "wpctl set-mute @DEFAULT_SINK@ toggle";
            on-click-right = "crosspipe";
          };

          # Hidden on machines without a bluetooth controller.
          bluetooth = {
            format = "";
            format-off = " off";
            format-disabled = " off";
            format-no-controller = "";
            format-connected = " {device_alias}";
            format-connected-battery = " {device_alias} {device_battery_percentage}%";
            tooltip-format = "{controller_alias}\t{status}";
            tooltip-format-connected = "{controller_alias}\t{num_connections} connected\n\n{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}";
            tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_battery_percentage}%";
            max-length = 30;
            on-click = term "bluetui";
            on-click-right = "blueman-manager";
          };

          cpu = {
            format = "{}% ";
            on-click = term "btop --preset 1";
            states = {
              warning = 60;
              critical = 80;
            };
          };

          disk = {
            path = "/";
            format = "{specific_free:0.0f}GB ";
            unit = "GB";
            on-click = term "ncdu --exclude-kernfs --exclude /nix --exclude /boot /";
            states = {
              warning = 70;
              critical = 90;
            };
          };

          memory = {
            interval = 30;
            format = "{}% ";
            on-click = term "btop --preset 2";
            max-length = 10;
            states = {
              warning = 60;
              critical = 80;
            };
          };
        };

        carbon.waybar.style = builtins.readFile ./style.css;

        programs.waybar.enable = true;

        # Inherit the session PATH so on-click commands resolve.
        systemd.user.services.waybar.environment.PATH = lib.mkForce null;

        environment.etc."xdg/waybar/config".source = json.generate "waybar-config" cfg.settings;
        environment.etc."xdg/waybar/style.css".text = cfg.style;

        # switch-to-configuration doesn't restart user services, so signal any running
        # instance to reload its config after a switch.
        system.activationScripts.reloadWaybar = {
          deps = [ "etc" ];
          text = ''
            ${pkgs.procps}/bin/pkill -USR2 -x '\.?waybar(-wrapped)?' || true
          '';
        };
      };
    };
}
