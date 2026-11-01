# carbon

NixOS modules we share between our configs. Carbon doesn't set up your apps for you: your keybinds, themes and bar layout stay in your own config. What lives here are the fixes that make those apps actually work on NixOS, like systemd units, session wiring and a few helper scripts.

## Getting started

Add carbon to your flake inputs:

```nix
# flake.nix
inputs.carbon = {
  url = "github:owl-corp/carbon";
  inputs.nixpkgs.follows = "nixpkgs";
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

A tidy way to do it is to import carbon's module from your own module for the same app, so the app's config and its fixes sit together:

```nix
flake.nixosModules.waybar = {
  imports = [ inputs.carbon.nixosModules.waybar ];
  programs.waybar.enable = true;
};
```

Importing a module is how you opt in, and leaving it out is how you opt out. Any default carbon picks for you can be overridden with a normal assignment in your own config.

## Modules

### hyprland

Makes the rest of the desktop work when Hyprland is started without UWSM:

- **Screen sharing and portals.** Adds a `hyprland-session.target` that brings up the graphical session, which `xdg-desktop-portal` needs before it will start. Start it from your Hyprland config:

  ```sh
  systemctl --user import-environment PATH XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE && systemctl --user start hyprland-session.target
  ```

- **Clean logout.** When Hyprland exits, the session is stopped too, so your bar and portals don't crash-loop and stay dead after you log back in. This relies on `HYPRLAND_INSTANCE_SIGNATURE` being imported in the line above.
- **Keyring unlock.** hyprlock unlocks gnome-keyring when you log in, if gnome-keyring is enabled.
- **Electron apps.** Run on Wayland instead of XWayland, so screen sharing can see every monitor.

### regreet

If greetd logs you in automatically, gnome-keyring starts only partly set up and hyprlock can't unlock it. This finishes setting it up when the session starts.

### quickshell

Runs Quickshell as a user service for the graphical session. It sees the same `PATH` as your session, so commands in your config work, and it restarts after a rebuild so your changes show up straight away.

Put your config in `/etc/xdg/quickshell`.

### waybar

Waybar's on-click commands see your session's `PATH`, and running bars reload their config after a rebuild.

### openlogi

[OpenLogi](https://github.com/AprilNEA/OpenLogi) support for Logitech mice: device permissions plus the background agent, started with your session. The agent only looks for a mouse when it starts, and Bluetooth mice usually connect after you log in, so it gets restarted whenever a Logitech mouse connects.

### screenshot

A `screenshot` command for Wayland: it freezes the screen, lets you drag out an area, then saves it with rounded corners and copies it to the clipboard. Screenshots go to `~/Pictures/Screenshots`, or wherever `carbon.screenshot.directory` points. Bind it to a key in your compositor config.

### micMute

A `mic-mute` command that mutes or unmutes your default microphone for every app. If Discord or Vesktop is open, it also presses Discord's mute shortcut (Ctrl+Shift+M) in its window, so Discord's mute button and sound match. Bind it to a key in your Hyprland config. It needs Hyprland's Lua config, and expects Discord's mute shortcut to be the default.

If you mute from inside Discord, only Discord changes, and the two get out of step until you click Discord's button again.

### nautilus

Installs Nautilus. Set `carbon.nautilus.pythonExtensions.enable` to load extensions other packages install for Nautilus outside GNOME.

The usual extras are plain NixOS options: `services.gvfs.enable` for trash, network shares and USB drives, `services.gnome.sushi.enable` for space-bar previews, `programs.nautilus-open-any-terminal.enable` for an "Open in terminal" entry, and `ffmpegthumbnailer` in `environment.systemPackages` for video thumbnails.

### systemHelpers

Three commands for looking after your system:

- `system-rebuild` switches both your NixOS and home-manager configs.
- `system-update` runs every `modules/packages/*/update.sh`, updates `flake.lock`, rebuilds, then shows which packages and known security issues (CVEs) changed.
- `system-clean <age>` deletes old generations, e.g. `system-clean 7d`, and frees up the space they used.

They run from `/etc/nixos`. Symlink that to your checkout, or set `carbon.systemHelpers.flakePath`.

## Adding a module

Every `.nix` file under `modules/` is loaded automatically as a [flake-parts](https://flake.parts) module (via [import-tree](https://github.com/vic/import-tree)). When adding one:

- Only include what an app needs to work. Its actual settings belong in each person's own config.
- Keep personal details out: no names, emails, usernames or monitor setups. Add an option instead, or leave it to the consumer.
- Set any opinions with `lib.mkDefault`, so people can override them with a plain assignment.
- Inside these modules, `inputs` and `self` are carbon's, not the consumer's.

## Testing changes locally

Build your own config against your carbon checkout instead of the pushed version:

```sh
nixos-rebuild build --flake . --override-input carbon path:$HOME/src/carbon
```
