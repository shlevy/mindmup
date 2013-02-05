{ config, pkgs }:

with pkgs.lib;

let
  cfg = config.services.mindmup;

  usesKeys = (subString 0 (stringLength "/run/keys") cfg.awsSecretKeyFile) == "/run/keys";
in {
  options = {
    services.mindmup = {
      enable = mkOption {
        description = "Whether to enable the mindmup service";

        default = false;

        type = types.bool;
      };

      port = mkOption {
        description = "The port to listen on";

        default = 80;

        type = types.string;
      };

      googleAnalyticsId = mkOption {
        description = "Google analytics ID for tracking";

        default = "";

        type = types.string;
      };

      s3BucketName = mkOption {
        description = "S3 bucket to store files in";

        type = types.string;
      };

      awsKeyId = mkOption {
        description = "AWS access key ID with write access to the bucket";

        type = types.string;
      };

      awsSecretKeyFile = mkOption {
        description = "File containing the AWS secret key corresponding to the access key for the bucket";

        example = "/run/keys/s3-secret.key";

        type = types.string;
      };

      s3UploadFolder = mkOption {
        description = "The folder in the bucket where maps are stored";

        type = types.string;
      };

      s3Website = mkOption {
        description = "The domain where files in the bucket are publicly accessible";

        default = "${cfg.s3BucketName}.s3.amazonaws.com";

        type = types.string;
      };

      siteURL = mkOption {
        description = "The URL of this site, for s3 to redirect back to us";

        type = types.string;
      };

      jotFormId = mkOption {
        description = "ID of the form for feedback on JotForm";

        default = "";

        type = types.string;
      };

      shareThisId = mkOption {
        description = "ShareThis publisher ID to share links";

        default = "";

        type = types.string;
      };

      defaultMap = mkOption {
        description = "The default map to show on the home page";

        default = "default";

        type = types.string;
      };

      maxUploadSize = mkOption {
        description = "The maximum size users are allowed to upload, in kb";

        default = 100;

        type = types.int;
      };

      networkTimeout = mkOption {
        description = "Time to wait before reporting a timeout problem to users, in ms";

        default = 10000;

        type = types.int;
      };

      rackEnvironment = mkOption {
        description = "The stage of the application";

        default = "development";

        example = "production";

        type = types.string;
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.mindmup = {
      after = [ "network.target" ] ++ optional usesKeys "keys.target";

      requires = optional usesKeys "keys.target";

      bindsTo = [ "network.target" ];

      wantedBy = [ "multi-user.target" ];

      description = "Zero-friction mind map canvas";

      environment = {
        RACK_ENV = cfg.rackEnvironment;

        GOOGLE_ANALYTICS_ACCOUNT = cfg.googleAnalyticsAccount;

        S3_BUCKET_NAME = cfg.s3BucketName;

        S3_KEY_ID = cfg.awsKeyId;

        S3_UPLOAD_FOLDER = cfg.s3UploadFolder;

        S3_WEBSITE = cfg.s3Website;

        SITE_URL = cfg.siteURL;

        JOTFORM_CONTACT = cfg.jotFormId;

        SHARETHIS_PUB = cfg.shareThisId;

        DEFAULT_MAP = cfg.defaultMap;

        MAX_UPLOAD_SIZE = toString cfg.maxUploadSize;

        NETWORK_TIMEOUT_MILLIS = toString cfg.networkTimeout;

        CURRENT_MAP_DATA_VERSION = "a1";

        GEM_PATH = with pkgs.lib.rubyGems; makeSearchPath pkgs.ruby.gemPath [
          sinatra_1_3_2
          uuid
          aws_sdk
          thin
        ];
      };

      preStart = ''
        mkdir -m 700 -p /var/lib/mindmup
        if ! test -f /var/lib/mindmup/session.secret; then
            cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 > /var/lib/mindmup/session.secret
            chmod 400 /var/lib/mindmup/session.secret
        fi
      '';

      script = ''
        export S3_SECRET_KEY=$(cat ${cfg.awsSecretKeyFile})
        export RACK_SESSION_SECRET=$(cat /var/lib/mindmup/session.secret)
        cd ${../.}
        exec ${pkgs.rubyLibs.rack}/bin/rackup config.ru -p ${toString cfg.port}
      '';
    };
  };
}
