let
  mindmup = { config, resources, nodes, ... }: {
    require = [ ./mindmup.nix ];
    ec2.metadata = true;
    services.mindmup = {
      enable = true;
      s3BucketName = resources.s3Buckets."mindmup-bucket".name;
      siteURL = "http://${nodes.proxy.config.networking.publicIPv4}/";
    };
  };
in {
  network.description = "mindmup";
  backend1 = mindmup;
  backend2 = mindmup;
  proxy = { nodes, ... }: {
    deployment.encryptedLinksTo = [ "backend1" "backend2" ];
    services.httpd = {
      enable = true;
      adminAddr = "charon@example.com";
      extraModules = [ "proxy_balancer" ];
      extraConfig = ''
        <Proxy balancer://cluster>
          Allow from all
          BalancerMember http://backend1-encrypted:${builtins.toString nodes.backend1.config.services.mindmup.port} retry=0 route=1
          BalancerMember http://backend2-encrypted:${builtins.toString nodes.backend2.config.services.mindmup.port} retry=0 route=2
          ProxySet stickysession=ROUTEID
        </Proxy>

        ProxyPreserveHost On

        ProxyPass / balancer://cluster/
        ProxyPassReverse / balancer://cluster/
      '';
    };
  };
}
