# carbon

Shared NixOS and home-manager extras, exported as plain `nixosModules.*`. Internally every `.nix` file under `modules/` is a [flake-parts](https://flake.parts) module, loaded with [import-tree](https://github.com/vic/import-tree).

## Usage

```nix
# flake.nix
inputs.carbon = {
  url = "git+ssh://git@github.com/owl-corp/carbon";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
```

Then import the modules you want into a host:

```nix
nixosSystem {
  modules = [
    inputs.carbon.nixosModules.hyprland
    inputs.carbon.nixosModules.systemHelpers
    # ...
  ];
}
```

Carbon doesn't configure apps for you. Each consumer keeps their own config for an app (keybinds, themes, bar layout) and carbon holds the fixes that go with it: systemd units, session plumbing, and small tools. A handy pattern is to import carbon's module from your own module for that app:

```nix
flake.nixosModules.waybar = {
  imports = [ inputs.carbon.nixosModules.waybar ];
  programs.waybar.enable = true;
};
```

- `nixosModules.hyprland`: `hyprland-session.target` (start it from your hyprland config so `xdg-desktop-portal` runs), hyprlock gnome-keyring PAM, `NIXOS_OZONE_WL`.
- `nixosModules.regreet`: initialises gnome-keyring components when greetd auto-logs in (`initial_session`).
- `nixosModules.waybar`: lets the user service inherit the session `PATH`; reloads running instances after a switch.
- `nixosModules.quickshell`: a `quickshell` user service on `graphical-session.target` with the session `PATH`, restarted after a switch; pick a config with `carbon.quickshell.config`. Put your config in `/etc/xdg/quickshell`.
- `nixosModules.nautilus`: Nautilus, with opt-in `carbon.nautilus.{gvfs,sushi,thumbnails,pythonExtensions,openAnyTerminal}.enable`.
- `nixosModules.systemHelpers`: `system-rebuild`, `system-update` and `system-clean`. They run from `/etc/nixos` (symlink it to your checkout), or set `carbon.systemHelpers.flakePath`.

Opinions are set with `lib.mkDefault`, so a plain assignment overrides them. To drop a module, don't import it.

## Writing modules

- Only extras that make an app work; leave the app's own config to the consumer.
- No personal values (names, emails, usernames, monitors); expose an option or leave it to the consumer.
- Set opinions with `lib.mkDefault` so consumers can override with a plain assignment.
- `inputs` and `self` refer to carbon, not the consumer.

## Local development

```sh
nixos-rebuild build --flake . --override-input carbon path:$HOME/src/carbon
```
