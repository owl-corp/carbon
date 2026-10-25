{ self, inputs, ... }: {
  flake.nixosModules.regreet = { config, lib, ... }: {
    # Auto-login starts gnome-keyring without its components, so hyprlock's PAM unlock fails until something initialises them.
    systemd.user.services.gnome-keyring-start = lib.mkIf (config.services.greetd.settings ? initial_session && config.services.gnome.gnome-keyring.enable) {
      description = "Initialise gnome-keyring components before the session is unlocked";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.security.wrapperDir}/gnome-keyring-daemon --start --components=secrets";
      };
    };
  };
}
