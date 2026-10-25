{ self, inputs, ... }: {
  flake.nixosModules.nautilus = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.nautilus;
    in {
      options.carbon.nautilus = {
        gvfs.enable = lib.mkEnableOption "gvfs for trash, network shares and removable media";
        sushi.enable = lib.mkEnableOption "Sushi quick previews (space bar)";
        thumbnails.enable = lib.mkEnableOption "video thumbnails via ffmpegthumbnailer";
        pythonExtensions.enable = lib.mkEnableOption "loading nautilus-python extensions installed by other packages";
        openAnyTerminal.enable = lib.mkEnableOption "the \"Open in terminal\" context menu entry";
      };

      config = lib.mkMerge [
        { environment.systemPackages = [ pkgs.nautilus ]; }

        (lib.mkIf cfg.gvfs.enable { services.gvfs.enable = true; })
        (lib.mkIf cfg.sushi.enable { services.gnome.sushi.enable = true; })

        # Nautilus discovers thumbnailers through XDG_DATA_DIRS, so it must be in a profile.
        (lib.mkIf cfg.thumbnails.enable { environment.systemPackages = [ pkgs.ffmpegthumbnailer ]; })

        (lib.mkIf cfg.pythonExtensions.enable {
          environment.systemPackages = [ pkgs.nautilus-python ];
          environment.sessionVariables = lib.mkIf (!config.services.desktopManager.gnome.enable) {
            NAUTILUS_4_EXTENSION_DIR = "${pkgs.nautilus-python}/lib/nautilus/extensions-4";
          };
          environment.pathsToLink = [ "/share/nautilus-python/extensions" ];
        })

        (lib.mkIf cfg.openAnyTerminal.enable {
          carbon.nautilus.pythonExtensions.enable = true;
          programs.nautilus-open-any-terminal.enable = true;
        })
      ];
    };
}
