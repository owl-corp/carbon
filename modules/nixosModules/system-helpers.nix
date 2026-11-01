{ self, inputs, ... }: {
  flake.nixosModules.systemHelpers = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.systemHelpers;

      # Switches the NixOS system and home-manager configs to the local checkout
      # as-is, without running update scripts or touching flake.lock.
      system-rebuild = pkgs.writeShellApplication {
        name = "system-rebuild";
        runtimeInputs = [ pkgs.nix-output-monitor pkgs.home-manager ];
        text = ''
          cd "''${NIXCFG:-${cfg.flakePath}}"

          # Prompt for the password now, before nom takes over the terminal.
          sudo -v
          nixos-rebuild switch --sudo --flake . --log-format internal-json -v |& nom --json
          home-manager switch --flake . --log-format internal-json -v |& nom --json
        '';
      };

      # Prints the package and CVE changes between generations, via nvd and
      # vulnix, with the unversioned noise filtered out.
      system-diff = pkgs.writers.writePython3Bin "system-diff" {
        makeWrapperArgs = [ "--prefix" "PATH" ":" "${lib.makeBinPath [ pkgs.nvd pkgs.vulnix ]}" ];
        flakeIgnore = [ "E501" ];
      } (builtins.readFile ./system-diff.py);

      # Runs every package's update.sh, updates flake.lock, then runs system-rebuild and system-diff.
      # Works on the checkout, not the store copy, because the updates write to it.
      system-update = pkgs.writeShellApplication {
        name = "system-update";
        runtimeInputs = [ system-rebuild system-diff ];
        text = ''
          cd "''${NIXCFG:-${cfg.flakePath}}"

          hm_profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
          old_system=$(readlink -f /run/current-system)
          old_home=$(readlink -f "$hm_profile")

          shopt -s nullglob
          for script in modules/packages/*/update.sh; do
            echo "==> $script"
            "$script"
          done

          nix flake update

          system-rebuild

          echo
          system-diff \
            System "$old_system" "$(readlink -f /run/current-system)" \
            Home "$old_home" "$(readlink -f "$hm_profile")"
        '';
      };

      # Deletes generations older than <age> (e.g. 30d), then garbage-collects.
      # Runs as both the user and root, since each can only see its own profiles.
      system-clean = pkgs.writeShellApplication {
        name = "system-clean";
        text = ''
          if [ $# -lt 1 ]; then
            echo "usage: system-clean <age> [nix-collect-garbage options]" >&2
            echo "  e.g. system-clean 30d" >&2
            exit 1
          fi
          age="$1"
          shift

          nix-collect-garbage --delete-older-than "$age" "$@"
          sudo nix-collect-garbage --delete-older-than "$age" "$@"
        '';
      };
    in {
      options.carbon.systemHelpers.flakePath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nixos";
        example = "$HOME/src/nixcfg";
        description = ''
          Checkout of the system flake, expanded by the shell at run time.
          The NIXCFG environment variable overrides it. The default works when
          /etc/nixos is a symlink to the checkout.
        '';
      };

      config.environment.systemPackages = [ system-rebuild system-update system-clean ];
    };
}
