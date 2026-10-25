{ self, inputs, ... }: {
  flake.nixosModules.screenshot = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.screenshot;
      screenshot = pkgs.writeShellApplication {
        name = "screenshot";
        runtimeInputs = with pkgs; [ wayfreeze slurp grim imagemagick wl-clipboard procps coreutils ];
        text = ''
          # Freeze the screen first so menus and tooltips stay put while you select.
          if [ "''${1:-}" != --capture ]; then
            exec wayfreeze --hide-cursor --inverse-transform --after-freeze-cmd "$0 --capture"
          fi
          trap 'pkill -x wayfreeze' EXIT
          geom=$(slurp)
          dir="${cfg.directory}"
          mkdir -p "$dir"
          file="$dir/$(date +%F_%H-%M-%S).png"
          grim -g "$geom" - | magick - \
            \( +clone -alpha transparent -fill white -draw "roundrectangle 0,0 %[fx:w-1],%[fx:h-1] 12,12" \) \
            -compose DstIn -composite "$file"
          wl-copy --type image/png < "$file"
        '';
      };
    in {
      options.carbon.screenshot.directory = lib.mkOption {
        type = lib.types.str;
        default = "$HOME/Pictures/Screenshots";
        example = "/data/screenshots";
        description = "Where screenshots are saved, expanded by the shell at run time.";
      };

      config.environment.systemPackages = [ screenshot ];
    };
}
