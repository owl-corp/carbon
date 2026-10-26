{ self, inputs, ... }: {
  flake.nixosModules.nautilus = { config, pkgs, lib, ... }: {
    options.carbon.nautilus.pythonExtensions.enable =
      lib.mkEnableOption "loading nautilus-python extensions installed by other packages";

    config = lib.mkMerge [
      { environment.systemPackages = [ pkgs.nautilus ]; }

      (lib.mkIf config.carbon.nautilus.pythonExtensions.enable {
        environment.systemPackages = [ pkgs.nautilus-python ];
        environment.sessionVariables = lib.mkIf (!config.services.desktopManager.gnome.enable) {
          NAUTILUS_4_EXTENSION_DIR = "${pkgs.nautilus-python}/lib/nautilus/extensions-4";
        };
        environment.pathsToLink = [ "/share/nautilus-python/extensions" ];
      })
    ];
  };
}
