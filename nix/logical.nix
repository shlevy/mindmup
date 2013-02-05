let
  defaultAwsKeyId = 
    let
      res = builtins.getEnv "EC2_ACCESS_KEY";
    in if res == ""
      then throw "You must either set the awsKeyId argument or define the EC2_ACCESS_KEY env var"
      else res;

  defaultAwsSecretKey = 
    let
      res = builtins.getEnv "EC2_SECRET_KEY";
    in if res == ""
      then throw "You must either set the awsSecretKey argument or define the EC2_ACCESS_KEY env var"
      else res;
in
{ environment ? "production"
, googleAnalyticsId ? ""
, awsKeyId ? defaultAwsKeyId
, awsSecretKey ? defaultAwsSecretKey
, jotFormId ? ""
, shareThisId ? ""
, maxUploadSize ? 100
, networkTimeout ? 10000
}:

{
  network.name = "mindmup";

  machine = { config, resources, ... }: {
    deployment = {
      storeKeysOnMachine = false;

      keys."s3-secret.key" = awsSecretKey;
    };

    require = [ ./mindmup.nix ];

    services.mindmup = {
      enable = true;

      inherit googleAnalyticsId awsKeyId jotFormId shareThisId maxUploadSize networkTimeout;

      s3BucketName = resources.s3Buckets.mindmup.name;

      awsSecretKeyFile = "/run/keys/s3-secret.key";

      s3UploadFolder = "maps";

      siteURL = "http://${config.networking.publicIPv4}";

      rackEnvironment = environment;
    };
  };
}
