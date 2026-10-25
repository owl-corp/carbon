{ self, inputs, ... }: {
  flake.nixosModules.systemHelpers = { config, pkgs, lib, ... }:
    let
      cfg = config.carbon.systemHelpers;

      # Switches the NixOS system and home-manager configs to the local checkout
      # as-is, without running update scripts or touching flake.lock.
      system-rebuild =
        { writeShellApplication, nix-output-monitor, home-manager, ... }:
        writeShellApplication {
          name = "system-rebuild";
          runtimeInputs = [ nix-output-monitor home-manager ];
          text = ''
            cd "''${NIXCFG:-${cfg.flakePath}}"

            # Prompt for the password now, before nom takes over the terminal.
            sudo -v
            # Evaluate as the user so private git+ssh inputs use their SSH keys.
            nixos-rebuild switch --sudo --flake . --log-format internal-json -v |& nom --json
            home-manager switch --flake . --log-format internal-json -v |& nom --json
          '';
        };

      # Prints the package changes between generations, via nvd with the
      # unversioned noise filtered out.
      system-diff =
        { writers, nvd, ... }:
        writers.writePython3Bin "system-diff" {
          makeWrapperArgs = [ "--prefix" "PATH" ":" "${lib.makeBinPath [ nvd ]}" ];
          flakeIgnore = [ "E501" ];
        } (builtins.readFile ./system-diff.py);

      # Runs every package's update.sh and updates flake.lock, then hands off to
      # system-rebuild to switch the NixOS system and home-manager configs, and
      # finishes with what changed. Works on the checkout rather than the store
      # copy of this flake, as the updates write back into it.
      system-update =
        { writeShellApplication, system-rebuild, system-diff, ... }:
        writeShellApplication {
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

      # Deletes profile generations older than <age> (any `--delete-older-than`
      # value, e.g. 30d), then garbage-collects the store. Runs once as the user
      # (home-manager, ~/.local/state/nix/profiles) and once as root (system,
      # /nix/var/nix/profiles), as neither run reaches the other's profiles.
      system-clean =
        { writeShellApplication, ... }:
        writeShellApplication {
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

      rebuild = pkgs.callPackage system-rebuild { };
    in {
      options.carbon.systemHelpers.flakePath = lib.mkOption {
        type = lib.types.str;
        example = "$HOME/src/nixcfg";
        description = ''
          Checkout of the system flake, expanded by the shell at run time.
          The NIXCFG environment variable overrides it.
        '';
      };

      config.environment.systemPackages = [
        rebuild
        (pkgs.callPackage system-update {
          system-rebuild = rebuild;
          system-diff = pkgs.callPackage system-diff { };
        })
        (pkgs.callPackage system-clean { })
      ];
    };
}
