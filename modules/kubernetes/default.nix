{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg = config.services.k8s;
  opt = options.services.k8s;

  mkKubeConfig = name: conf: pkgs.writeText "${name}-kubeconfig" (builtins.toJSON {
    apiVersion = "v1";
    kind = "Config";
    clusters = [{
      name = "local";
      cluster.certificate-authority = conf.caFile or cfg.caFile;
      cluster.server = conf.server;
    }];
    users = [{
      inherit name;
      user = {
        client-certificate = conf.certFile;
        client-key = conf.keyFile;
      };
    }];
    contexts = [{
      context = {
        cluster = "local";
        user = name;
      };
      name = "local";
    }];
    current-context = "local";
  });

  mkCert = { name, CN, hosts ? [], fields ? {}, action ? "",
             privateKeyOwner ? "kubernetes" }: rec {
    inherit name caCert CN hosts fields action;
    cert = secret name;
    key = secret "${name}-key";
    privateKeyOptions = {
      owner = privateKeyOwner;
      group = "nogroup";
      mode = "0600";
      path = key;
    };
  };

  mkKubeConfigOptions = prefix: {
    server = mkOption {
      description = "${prefix} kube-apiserver server address.";
      type = types.str;
    };

    caFile = mkOption {
      description = "${prefix} certificate authority file used to connect to kube-apiserver.";
      type = types.nullOr types.path;
      default = cfg.caFile;
      defaultText = literalExpression "config.${opt.caFile}";
    };

    certFile = mkOption {
      description = "${prefix} client certificate file used to connect to kube-apiserver.";
      type = types.nullOr types.path;
      default = null;
    };

    keyFile = mkOption {
      description = "${prefix} client key file used to connect to kube-apiserver.";
      type = types.nullOr types.path;
      default = null;
    };
  };
in {

  imports = [
    ./kubelet.nix
    ./cni.nix
    ./cri.nix
    ./containerd.nix
  ];

  ###### interface

  options.services.k8s = {
    lib = mkOption {
      description = "Common functions for the kubernetes modules.";
      default = {
        inherit mkCert;
        inherit mkKubeConfig;
        inherit mkKubeConfigOptions;
      };
      type = types.attrs;
    };

    dataDir = mkOption {
      description = "Kubernetes root directory for managing kubelet files.";
      default = "/var/lib/kubernetes";
      type = types.path;
    };
  };

  ###### implementation

  config = mkMerge [


    (mkIf (
        cfg.kubelet.enable
    ) {
      systemd.targets.kubernetes = {
        description = "Kubernetes";
        wantedBy = [ "multi-user.target" ];
      };

      systemd.tmpfiles.rules = [
        "d /opt/cni/bin 0755 root root -"
        "d /run/kubernetes 0755 kubernetes kubernetes -"
        "d /var/lib/kubernetes 0755 kubernetes kubernetes -"
      ];

      users.users.kubernetes = {
        uid = config.ids.uids.kubernetes;
        description = "Kubernetes user";
        group = "kubernetes";
        home = cfg.dataDir;
        createHome = true;
      };
      users.groups.kubernetes.gid = config.ids.gids.kubernetes;
    })
  ];
}
