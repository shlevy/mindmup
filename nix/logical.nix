{ environment ? "production"
, googleAnalyticsId ? ""
, jotFormId ? ""
, shareThisId ? ""
, maxUploadSize ? 100
, networkTimeout ? 10000
}:

{
  network.name = "mindmup";

  machine = { config, resources, ... }: {
    require = [ ./mindmup.nix ];

    services.mindmup = {
      enable = true;

      inherit googleAnalyticsId jotFormId shareThisId maxUploadSize networkTimeout;

      getAWSCredentialsFromEC2Metadata = true;

      s3BucketName = resources.s3Buckets.mindmup.name;

      s3UploadFolder = "maps";

      siteURL = "http://${config.networking.publicIPv4}";

      rackEnvironment = environment;
    };
  };
}
