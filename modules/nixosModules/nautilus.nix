{ self, inputs, ... }: {
  flake.nixosModules.nautilus = { pkgs, lib, ... }: {
    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = lib.mkDefault "ghostty";
    };
    services.gvfs.enable = true;
    services.gnome.sushi.enable = true;

    environment.systemPackages = with pkgs; [
      nautilus
      ffmpegthumbnailer
    ];
  };
}
