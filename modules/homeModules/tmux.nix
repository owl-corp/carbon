{ self, inputs, ... }: {
  flake.homeModules.tmux = { pkgs, lib, ... }:
    let
      # Not in nixpkgs; bump rev + hash together.
      themepack = pkgs.tmuxPlugins.mkTmuxPlugin {
        pluginName = "themepack";
        version = "0-unstable-2019-12-22";
        src = pkgs.fetchurl {
          url = "https://github.com/jimeh/tmux-themepack/archive/7c59902f64dcd7ea356e891274b21144d1ea5948.tar.gz";
          hash = "sha256-0hAFCSgxy8nG2ZDEIkKxAJGCWVZykykVLDnY7ZHDWHk=";
        };
      };
      current-pane-hostname = pkgs.tmuxPlugins.mkTmuxPlugin {
        pluginName = "current-pane-hostname";
        version = "0-unstable-2025-12-15";
        src = pkgs.fetchurl {
          url = "https://github.com/soyuka/tmux-current-pane-hostname/archive/0a8a187afcdf258e32a6b014105c12d344b670a5.tar.gz";
          hash = "sha256-mvKWtAIOz61xms4E3oUgrAEyLyKJCDo55Na+zy5aGtA=";
        };
      };
    in {
      programs.tmux = {
        enable = true;
        # sensible is loaded first by home-manager (sensibleOnTop), but the
        # options below are set after it, so restate the ones sensible changes.
        terminal = lib.mkDefault "tmux-256color";
        escapeTime = lib.mkDefault 0;
        focusEvents = lib.mkDefault true;
        aggressiveResize = lib.mkDefault true;

        mouse = lib.mkDefault true;
        historyLimit = lib.mkDefault 5000;
        baseIndex = lib.mkDefault 1;

        # A plain assignment replaces the whole list, theme included.
        plugins = lib.mkDefault (with pkgs.tmuxPlugins; [
          {
            plugin = themepack;
            extraConfig = "set -g @themepack 'powerline/default/cyan'";
          }
          prefix-highlight
          better-mouse-mode
          {
            # Set after the theme (which overwrites status-right) and before
            # this plugin, which swaps #U/#H for the pane's SSH user/host.
            plugin = current-pane-hostname;
            extraConfig = ''
              set -g status-right '#[fg=cyan,bold] #U@#H #[default]#[fg=blue]#(tmux display-message -p "#{pane_current_path}" | sed "s#$HOME#~#g") #[fg=red]%H:%M %d-%b-%y#[default]'
            '';
          }
        ]);

        extraConfig = ''
          setw -g automatic-rename on
          set -g renumber-windows on
          set -g set-titles on

          bind S setw synchronize-panes
        '';
      };
    };
}
