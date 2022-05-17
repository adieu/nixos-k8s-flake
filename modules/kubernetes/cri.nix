{ config, lib, options, pkgs, ... }:

with lib;

let
  top = config.services.k8s;
  cfg = top.cri;

  defaultContainerdSettings = {
    version = 2;
    root = "/var/lib/containerd";
    state = "/run/containerd";
    oom_score = 0;

    grpc = {
      address = "/run/containerd/containerd.sock";
    };

    plugins."io.containerd.grpc.v1.cri" = {
      sandbox_image = "pause:latest";

      cni = {
        bin_dir = "/opt/cni/bin";
        conf_dir = "/etc/cni/net.d";
        max_conf_num = 0;
      };

      containerd.runtimes.runc = {
        runtime_type = "io.containerd.runc.v2";
        options.SystemdCgroup = true;
      };
    };
  };

  infraContainer = pkgs.dockerTools.buildImage {
    name = "pause";
    tag = "latest";
    contents = top.kubelet.package.pause;
    config.Cmd = ["/bin/pause"];
  };

in {

  ###### interface
  options.services.k8s.cri = with lib.types; {

    enable = mkEnableOption "Kubernetes cri.";

    seedDockerImages = mkOption {
      description = "List of docker images to preload on system";
      default = [];
      type = listOf package;
    };

    containerRuntimeEndpoint = mkOption {
      description = "Endpoint at which to find the container runtime api interface/socket";
      type = str;
      default = "unix:///run/containerd/containerd.sock";
    };
  };

  ###### implementation

  config = mkMerge [
    (mkIf cfg.enable {
      services.k8s.cri.seedDockerImages = [infraContainer];

      # containerd configrations
      services.k8s.cri.containerd = {
        enable = mkDefault true;
        settings = mapAttrsRecursive (name: mkDefault) defaultContainerdSettings;
      };

      environment.systemPackages = [ pkgs.cri-tools ];

      systemd.services.containerd-seed-images = {
        description = "CNI Initialization";
        wantedBy = [ "kubernetes.target" ];
        after = [ "network.target" "containerd.service" ];
        before = [ "kubelet.service" ];
        script = ''
          ${concatMapStrings (img: ''
            echo "Seeding container image: ${img}"
            ${if (lib.hasSuffix "gz" img) then
              ''${pkgs.gzip}/bin/zcat "${img}" | ${pkgs.containerd}/bin/ctr -n k8s.io image import --all-platforms -''
            else
              ''${pkgs.coreutils}/bin/cat "${img}" | ${pkgs.containerd}/bin/ctr -n k8s.io image import --all-platforms -''
            }
          '') cfg.seedDockerImages}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      # containerd configurations from https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
      boot.kernel.sysctl = {
        "net.bridge.bridge-nf-call-iptables"  = 1;
        "net.ipv4.ip_forward"                 = 1;
        "net.bridge.bridge-nf-call-ip6tables" = 1;
      };
      boot.kernelModules = ["br_netfilter" "overlay"];

    }
  )];
}
