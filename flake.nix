{
  description = "Kubernetes Flake";

  inputs = {};

  outputs = { self, ... }@inputs:
  {
    overlay = import ./overlays;
    nixosModule = import ./modules/kubernetes;
    nixosModules = {
      kubernetes = self.nixosModule;
    };
  };
}
