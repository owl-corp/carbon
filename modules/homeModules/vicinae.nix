{ self, inputs, ... }: {
  flake.homeModules.vicinae = { lib, ... }: {
    programs.vicinae = {
      enable = true;
      systemd.enable = true;
      mutableSettings = lib.mkDefault true;
      # Vicinae writes its own Firefox native-messaging manifest; HM's copy collides with it.
      enableFirefoxIntegration = false;

      settings = {
        theme.dark.name = lib.mkDefault "dracula";
        # Opened with Mod+R from hyprland.lua; an empty toggle disables the global bind.
        global_shortcuts.toggle = "";
      };
    };
  };
}
