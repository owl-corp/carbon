{ self, inputs, ... }: {
  flake.nixosModules.hyprland = { config, lib, ... }: {
    security.pam.services.hyprlock.enableGnomeKeyring = lib.mkDefault config.services.gnome.gnome-keyring.enable;

    # Electron apps default to XWayland, where screen sharing only sees one monitor.
    environment.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";

    # xdg-desktop-portal >= 1.22 refuses to start unless
    # graphical-session.target is active, and Hyprland without UWSM never
    # activates it. That target is RefuseManualStart, so bind it to a session
    # target Hyprland can start itself. Without this, screen sharing has no
    # ScreenCast portal. Start it from hyprland.lua with:
    #   systemctl --user import-environment PATH XDG_SESSION_TYPE && systemctl --user start hyprland-session.target
    systemd.user.targets.hyprland-session = {
      description = "Hyprland compositor session";
      documentation = [ "man:systemd.special(7)" ];
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
    };
  };
}
