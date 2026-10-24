# Not under modules/, so consumers don't import it twice alongside their own.
{ inputs, ... }: {
  imports = [
    inputs.flake-parts.flakeModules.flakeModules
    inputs.home-manager.flakeModules.home-manager
  ];

  config = {
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
