let
  mindmup =
    { resources, nodes, ... }:
    { require = [ ./mindmup.nix ];
      services.mindmup.enable = true;
      services.mindmup.siteURL = "http://${
        nodes.proxy.config.networking.publicIPv4}/";
    };
in {
  network.description = "mindmup";

  backend1 = mindmup;
  backend2 = mindmup;
  proxy =
    { nodes, ... }:
    { services.httpd.enable = true;
      services.httpd.adminAddr = "charon@example.com";
      services.httpd.extraModules = [ "proxy_balancer" ];
      services.httpd.extraConfig = ''
        <Proxy balancer://cluster>
          Allow from all
          BalancerMember http://backend1-encrypted:${
            toString nodes.backend1.config.services.mindmup.port
          } retry=0 route=1
          BalancerMember http://backend2-encrypted:${
            toString nodes.backend2.config.services.mindmup.port
          } retry=0 route=2
          ProxySet stickysession=ROUTEID
        </Proxy>
        ProxyPreserveHost On
        ProxyPass / balancer://cluster/
        ProxyPassReverse / balancer://cluster/
      '';
    };
}
