{ self, inputs, ... }: {
  flake.nixosModules.micMute = { config, pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "mic-mute";
        runtimeInputs = with pkgs; [ wireplumber gnugrep config.programs.hyprland.package ];
        text = ''
          wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
          # Discord's own mute (Ctrl+Shift+M) doesn't show up in PipeWire, so toggle it too to keep its UI in sync.
          if hyprctl clients | grep -Eq '^\s*class: (vesktop|discord)$'; then
            hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "M", window = "class:vesktop|discord" })' >/dev/null
          fi
        '';
      })
    ];
  };
}
