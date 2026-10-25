# carbon

Shared NixOS and home-manager extras, built on [flake-parts](https://flake.parts) and [import-tree](https://github.com/vic/import-tree). Every `.nix` file under `modules/` is a flake-parts module, exported together as `flakeModules.default`.

## Usage

```nix
# flake.nix
inputs.carbon = {
  url = "git+ssh://git@github.com/owl-corp/carbon";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
  inputs.flake-parts.follows = "flake-parts";
  inputs.import-tree.follows = "import-tree";
};

outputs = inputs:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.carbon.flakeModules.default
      (inputs.import-tree ./modules)
    ];
  };
```

The consuming flake must import `inputs.home-manager.flakeModules.home-manager` itself.

Importing carbon only defines `self.homeModules.*`, `self.nixosModules.*` and `self.packages.*`; nothing is applied until a host or home lists it.

Carbon doesn't configure apps for you. Each consumer keeps their own config for an app (keybinds, themes, bar layout) and carbon holds the fixes that go with it: systemd units, session plumbing, and small tools. A carbon module shares its name with the app's, so it merges into the consumer's module of the same name:

- `nixosModules.hyprland`: `hyprland-session.target` (start it from your hyprland config so `xdg-desktop-portal` runs), hyprlock gnome-keyring PAM, `NIXOS_OZONE_WL`.
- `nixosModules.regreet`: initialises gnome-keyring components when greetd auto-logs in (`initial_session`).
- `nixosModules.waybar`: lets the user service inherit the session `PATH`; reloads running instances after a switch.
- `nixosModules.quickshell`: a `quickshell` user service on `graphical-session.target` with the session `PATH`, restarted after a switch; pick a config with `carbon.quickshell.config`. Put your config in `/etc/xdg/quickshell`.
- `nixosModules.nautilus`: Nautilus, with opt-in `carbon.nautilus.{gvfs,sushi,thumbnails,pythonExtensions,openAnyTerminal}.enable`.
- `nixosModules.systemHelpers`: `system-rebuild`, `system-update` and `system-clean`.

## Overriding

A local module with the same name merges with the shared one:

```nix
flake.nixosModules.nautilus = {
  carbon.nautilus.openAnyTerminal.enable = true;
  programs.nautilus-open-any-terminal.terminal = "kitty";
};
```

To replace a shared module entirely:

```nix
{ lib, ... }: {
  flake.nixosModules.waybar = lib.mkForce ({ ... }: { /* ... */ });
}
```

## Writing modules

- Only extras that make an app work; leave the app's own config to the consumer.
- No personal values (names, emails, usernames, monitors); expose an option or leave it to the consumer.
- Set opinions with `lib.mkDefault` so consumers can override with a plain assignment.
- `inputs` and `self` refer to the consuming flake.

## Local development

```sh
nixos-rebuild build --flake . --override-input carbon path:$HOME/src/carbon
```
