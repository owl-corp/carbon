{ self, inputs, ... }: {
  flake.nixosModules.openlogi = { pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.openlogi ];
    services.udev.packages = [ pkgs.openlogi ];

    # Packaged unit lives under share/, which systemd.packages ignores.
    systemd.user.services.openlogi-agent = {
      description = "OpenLogi background agent";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.openlogi}/bin/openlogi-agent";
        Restart = "on-failure";
        RestartSec = 5;
      };
      environment.PATH = lib.mkForce null;
    };

    # The agent only looks for a mouse at startup, and Bluetooth mice connect later.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", ATTRS{id/vendor}=="046d", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="openlogi-agent-restart.service"
    '';
    systemd.user.services.openlogi-agent-restart = {
      description = "Restart OpenLogi agent after a Logitech mouse connects";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl --user try-restart openlogi-agent.service";
      };
    };
  };
}
