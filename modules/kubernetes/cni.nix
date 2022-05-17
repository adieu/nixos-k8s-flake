{ config, lib, pkgs, ... }:

with lib;

let
  top = config.services.k8s;
  cfg = top.cni;

  cniConfig =
    if cfg.config != [] && cfg.configDir != null then
      throw "Verbatim CNI-config and CNI configDir cannot both be set."
    else if cfg.configDir != null then
      cfg.configDir
    else
      (pkgs.buildEnv {
        name = "kubernetes-cni-config";
        paths = imap (i: entry:
          pkgs.writeTextDir "${toString (10+i)}-${entry.name}.conflist" (builtins.toJSON entry)
        ) cfg.config;
      });

in
{

  ###### interface
  options.services.k8s.cni = with lib.types; {

    enable = mkEnableOption "Kubernetes cni.";

    packages = mkOption {
      description = "List of network plugin packages to install.";
      type = listOf package;
      default = [];
    };

    config = mkOption {
      description = "Kubernetes CNI configuration.";
      type = listOf attrs;
      default = [];
      example = literalExpression ''
        [{
          "cniVersion": "0.4.0",
          "name": "podman",
          "plugins": [
            {
              "type": "bridge",
              "bridge": "cni-podman0",
              "isGateway": true,
              "ipMasq": true,
              "hairpinMode": true,
              "ipam": {
                "type": "host-local",
                "routes": [
                  {
                    "dst": "0.0.0.0/0"
                  }
                ],
                "ranges": [
                  [
                    {
                      "subnet": "10.88.0.0/16",
                      "gateway": "10.88.0.1"
                    }
                  ]
                ]
              }
            },
            {
              "type": "portmap",
              "capabilities": {
                "portMappings": true
              }
            },
            {
              "type": "firewall"
            },
            {
              "type": "tuning"
            }
          ]
        }]
      '';
    };

    configDir = mkOption {
      description = "Path to Kubernetes CNI configuration directory.";
      type = nullOr path;
      default = null;
    };

  };

  ###### implementation
  config = mkMerge [
    (mkIf cfg.enable {

      environment.etc."cni/net.d".source = cniConfig;

      systemd.services.cni-init = {
        description = "CNI Initialization";
        wantedBy = [ "kubernetes.target" ];
        after = [ "network.target" ];
        before = [ "kubelet.service" ];
        script = ''
          rm /opt/cni/bin/* || true
          ${concatMapStrings (package: ''
            echo "Linking cni package: ${package}"
            ln -fs ${package}/bin/* /opt/cni/bin
          '') cfg.packages}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      # Allways include cni plugins
      services.k8s.cni.packages = [pkgs.cni-plugins];
    })
  ];
}
