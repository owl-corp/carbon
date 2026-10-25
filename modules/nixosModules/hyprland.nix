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
    #   systemctl --user import-environment PATH XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE && systemctl --user start hyprland-session.target
    systemd.user.targets.hyprland-session = {
      description = "Hyprland compositor session";
      documentation = [ "man:systemd.special(7)" ];
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
    };

    # Nothing else ends the session when Hyprland exits, so its services
    # crash-loop until they hit the start limit and stay dead after the next login.
    systemd.user.services.hyprland-session-watch = {
      description = "Stop the graphical session when Hyprland exits";
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      script = ''
        pid=$(head -n1 "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock") || exit 0
        # A stale lock from a crashed instance would otherwise end the new session.
        kill -0 "$pid" 2>/dev/null || exit 0
        tail --pid="$pid" -f /dev/null
        systemctl --user stop --no-block graphical-session.target
      '';
    };
  };
}
