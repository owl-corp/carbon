{ self, inputs, ... }: {
  flake.nixosModules.waybar = { pkgs, lib, ... }: {
    # Inherit the session PATH so on-click commands resolve.
    systemd.user.services.waybar.environment.PATH = lib.mkForce null;

    # switch-to-configuration doesn't restart user services, so signal any running
    # instance to reload its config after a switch.
    system.activationScripts.reloadWaybar = {
      deps = [ "etc" ];
      text = ''
        ${pkgs.procps}/bin/pkill -USR2 -x '\.?waybar(-wrapped)?' || true
      '';
    };
  };
}
