{
  network.name = "mindmup";
  machine = { config, resources, ... }: {
    require = [ ./mindmup.nix ];
    ec2.metadata = true;
    services.mindmup = {
      enable = true;
      s3BucketName = resources.s3Buckets."mindmup-bucket".name;
      siteURL = "http://${config.networking.publicIPv4}/";
    };
    services.httpd = {
      enable = true;
      adminAddr = "charon@example.com";
      extraConfig = ''
        <Proxy *>
         Order deny,allow
         Allow from all
        </Proxy>

        ProxyPreserveHost On

        ProxyPass / http://machine:${builtins.toString config.services.mindmup.port}/ retry=5
        ProxyPassReverse / http://machine:${builtins.toString config.services.mindmup.port}/
      '';
    };
  };
}
