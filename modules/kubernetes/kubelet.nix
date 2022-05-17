{ config, lib, pkgs, ... }:

with lib;

let
  top = config.services.k8s;
  cfg = top.kubelet;

  mkKubeletConfig = conf: pkgs.writeText "kubeletconfig" (builtins.toJSON ({
    apiVersion = "kubelet.config.k8s.io/v1beta1";
    kind = "KubeletConfiguration";
    contentType = "application/vnd.kubernetes.protobuf";
    cgroupDriver = "systemd";
    hairpinMode = "hairpin-veth";
    staticPodPath = "/etc/kubernetes/manifests";
    authentication = {
      anonymous = {
        enabled = false;
      };
      webhook = {
        cacheTTL = "2m0s";
        enabled = true;
      };
      x509 = {
        clientCAFile = conf.clientCaFile;
      };
    };
    authorization = {
      mode = "Webhook";
      webhook = {
        cacheAuthorizedTTL = "5m0s";
        cacheUnauthorizedTTL = "30s";
      };
    };
    address = conf.address;
    port = conf.port;
    clusterDNS = [conf.clusterDns];
    clusterDomain = conf.clusterDomain;
    healthzBindAddress = conf.healthz.bind;
    healthzPort = conf.healthz.port;
    rotateCertificates = conf.rotateCertificates;
    registerNode = conf.registerNode;
    registerWithTaints = (mapAttrsToList (n: v: v) conf.taints);
    featureGates = conf.featureGates;
    tlsCertFile = conf.tlsCertFile;
    tlsPrivateKeyFile = conf.tlsKeyFile;
  })
  );

  kubeletConfig = mkKubeletConfig cfg;

  kubeconfig = top.lib.mkKubeConfig "kubelet" cfg.kubeconfig;

  manifestPath = "kubernetes/manifests";

  taintOptions = with lib.types; { name, ... }: {
    options = {
      key = mkOption {
        description = "Key of taint.";
        default = name;
        type = str;
      };
      value = mkOption {
        description = "Value of taint.";
        type = str;
      };
      effect = mkOption {
        description = "Effect of taint.";
        example = "NoSchedule";
        type = enum ["NoSchedule" "PreferNoSchedule" "NoExecute"];
      };
    };
  };
in
{

  ###### interface
  options.services.k8s.kubelet = with lib.types; {

    package = mkOption {
      description = "Kubernetes package to use.";
      type = types.package;
      default = pkgs.kubernetes;
      defaultText = literalExpression "pkgs.kubernetes";
    };

    path = mkOption {
      description = "Packages added to the services' PATH environment variable. Both the bin and sbin subdirectories of each package are added.";
      type = types.listOf types.package;
      default = [];
    };

    address = mkOption {
      description = "Kubernetes kubelet info server listening address.";
      default = "0.0.0.0";
      type = str;
    };

    clusterDns = mkOption {
      description = "Use alternative DNS.";
      default = "10.1.0.1";
      type = str;
    };

    clusterDomain = mkOption {
      description = "Use alternative domain.";
      default = config.services.kubernetes.addons.dns.clusterDomain;
      type = str;
    };

    clientCaFile = mkOption {
      description = "Kubernetes apiserver CA file for client authentication.";
      default = null;
      type = nullOr path;
    };

    containerRuntime = mkOption {
      description = "Which container runtime type to use";
      type = enum ["docker" "remote"];
      default = "remote";
    };

    enable = mkEnableOption "Kubernetes kubelet.";

    extraOpts = mkOption {
      description = "Kubernetes kubelet extra command line options.";
      default = "";
      type = separatedString " ";
    };

    featureGates = mkOption {
      description = "List set of feature gates";
      default = {};
      type = attrs;
    };

    rootDir = mkOption {
      description = "Kubernetes root directory for managing kubelet files.";
      default = top.dataDir;
      type = types.path;
    };

    healthz = {
      bind = mkOption {
        description = "Kubernetes kubelet healthz listening address.";
        default = "127.0.0.1";
        type = str;
      };

      port = mkOption {
        description = "Kubernetes kubelet healthz port.";
        default = 10248;
        type = int;
      };
    };

    hostname = mkOption {
      description = "Kubernetes kubelet hostname override.";
      default = config.networking.hostName;
      type = str;
    };

    kubeconfig = top.lib.mkKubeConfigOptions "Kubelet";

    manifests = mkOption {
      description = "List of manifests to bootstrap with kubelet (only pods can be created as manifest entry)";
      type = attrsOf attrs;
      default = {};
    };

    nodeIp = mkOption {
      description = "IP address of the node. If set, kubelet will use this IP address for the node.";
      default = null;
      type = nullOr str;
    };

    registerNode = mkOption {
      description = "Whether to auto register kubelet with API server.";
      default = true;
      type = bool;
    };

    port = mkOption {
      description = "Kubernetes kubelet info server listening port.";
      default = 10250;
      type = int;
    };

    taints = mkOption {
      description = "Node taints (https://kubernetes.io/docs/concepts/configuration/assign-pod-node/).";
      default = {};
      type = attrsOf (submodule [ taintOptions ]);
    };

    tlsCertFile = mkOption {
      description = "File containing x509 Certificate for HTTPS.";
      default = null;
      type = nullOr path;
    };

    tlsKeyFile = mkOption {
      description = "File containing x509 private key matching tlsCertFile.";
      default = null;
      type = nullOr path;
    };

    rotateCertificates = mkOption {
      description = "rotateCertificates enables client certificate rotation. The Kubelet will request a new certificate from the certificates.k8s.io API.";
      default = false;
      type = bool;
    };

    unschedulable = mkOption {
      description = "Whether to set node taint to unschedulable=true as it is the case of node that has only master role.";
      default = false;
      type = bool;
    };

    verbosity = mkOption {
      description = ''
        Optional glog verbosity level for logging statements. See
        <link xlink:href="https://github.com/kubernetes/community/blob/master/contributors/devel/logging.md"/>
      '';
      default = null;
      type = nullOr int;
    };

  };

  ###### implementation
  config = mkMerge [
    (mkIf cfg.enable {

      systemd.services.kubelet = {
        description = "Kubernetes Kubelet Service";
        wantedBy = [ "kubernetes.target" ];
        after = [ "containerd.service" "network.target" "kube-apiserver.service" "cni-init.service" "containerd-seed-images.service" ];
        path = with pkgs; [
          gitMinimal
          openssh
          util-linux
          iproute2
          ethtool
          thin-provisioning-tools
          iptables
          socat
        ] ++ lib.optional config.boot.zfs.enabled config.boot.zfs.package ++ cfg.path;
        serviceConfig = {
          Slice = "kubernetes.slice";
          CPUAccounting = true;
          MemoryAccounting = true;
          Restart = "on-failure";
          RestartSec = "1000ms";
          ExecStart = ''${cfg.package}/bin/kubelet \
            --config=${kubeletConfig} \
            --root-dir=${cfg.rootDir} \
            --container-runtime=${cfg.containerRuntime} \
            --container-runtime-endpoint=${top.cri.containerRuntimeEndpoint} \
            --kubeconfig=${kubeconfig} \
            --hostname-override=${cfg.hostname} \
            ${optionalString (cfg.nodeIp != null)
              "--node-ip=${cfg.nodeIp}"} \
            ${optionalString (cfg.verbosity != null) "--v=${toString cfg.verbosity}"} \
            ${cfg.extraOpts}
          '';
          WorkingDirectory = cfg.rootDir;
        };
        unitConfig = {
          StartLimitIntervalSec = 0;
        };
      };

      services.k8s.kubelet.hostname = with config.networking;
        mkDefault (hostName + optionalString (domain != null) ".${domain}");
    })

    (mkIf (cfg.enable && cfg.manifests != {}) {
      environment.etc = mapAttrs' (name: manifest:
        nameValuePair "${manifestPath}/${name}.json" {
          text = builtins.toJSON manifest;
          mode = "0755";
        }
      ) cfg.manifests;
    })

    (mkIf (cfg.enable && cfg.unschedulable) {
      services.k8s.kubelet.taints.unschedulable = {
        value = "true";
        effect = "NoSchedule";
      };
    })

  ];
}
