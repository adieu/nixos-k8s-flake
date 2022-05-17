final: prev:

{
  kubernetes_1_16_5 = final.callPackage ../pkgs/kubernetes/1.16.5 { };
  kubernetes_1_22_3 = final.callPackage ../pkgs/kubernetes/1.22.3 { };
}
