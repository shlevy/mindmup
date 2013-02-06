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
  };
}
