# carbon

Shared NixOS and home-manager modules, built on [flake-parts](https://flake.parts) and [import-tree](https://github.com/vic/import-tree). Every `.nix` file under `modules/` is a flake-parts module, exported together as `flakeModules.default`.

## Usage

```nix
# flake.nix
inputs.carbon = {
  url = "github:owl-corp/carbon";
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

## Overriding

A local module with the same name merges with the shared one:

```nix
flake.homeModules.tmux = { lib, ... }: {
  programs.tmux.historyLimit = lib.mkForce 50000;
};
```

To replace a shared module entirely:

```nix
{ lib, ... }: {
  flake.homeModules.tmux = lib.mkForce ({ ... }: { /* ... */ });
}
```

## Writing modules

- No personal values (names, emails, usernames, monitors); expose an option or leave it to the consumer.
- Set opinions with `lib.mkDefault` so consumers can override with a plain assignment.
- `inputs` and `self` refer to the consuming flake.

## Local development

```sh
nixos-rebuild build --flake . --override-input carbon path:$HOME/src/carbon
```
