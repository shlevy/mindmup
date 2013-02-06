{ config, pkgs, ... }:
with pkgs.lib;
let
  cfg = config.services.mindmup;
  rubyClosure = map ({ drv, ... }: drv) (genericClosure {
    startSet = with pkgs.rubyLibs; map (drv: { key = drv.outPath; inherit drv; }) [
      sinatra_1_3_2
      uuid
      aws_sdk
      thin
    ];
    operator = { key, drv }: map (drv:
      { key = drv.outPath; inherit drv; }
    ) (filter (p: p.isRubyGem or false) (drv.propagatedBuildNativeInputs or []));
  });
  usesEC2Metadata = cfg.awsKeyId == null;
  usesKeys = (!usesEC2Metadata) &&
    ((subString 0 (stringLength "/run/keys") cfg.awsSecretKeyFile) == "/run/keys");
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
        default = 5000;
        type = types.int;
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
        description = "AWS access key ID with write access to the bucket (null to use EC2 metadata)";
        default = null;
        type = types.nullOr types.string;
      };
      awsSecretKeyFile = mkOption {
        description = "File containing the AWS secret key corresponding to the access key for the bucket";
        example = "/run/keys/s3-secret.key";
        type = types.string;
      };
      s3UploadFolder = mkOption {
        description = "The folder in the bucket where maps are stored";
        default = "maps";
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
  config = mkMerge [ (mkIf cfg.enable {
    systemd.services.mindmup = {
      after = [ "network.target" ] ++ optional usesKeys "keys.target";
      requires = optional usesKeys "keys.target";
      bindsTo = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      description = "Zero-friction mind map canvas";
      environment = {
        RACK_ENV = cfg.rackEnvironment;
        GOOGLE_ANALYTICS_ACCOUNT = cfg.googleAnalyticsId;
        S3_BUCKET_NAME = cfg.s3BucketName;
        S3_UPLOAD_FOLDER = cfg.s3UploadFolder;
        S3_WEBSITE = cfg.s3Website;
        SITE_URL = cfg.siteURL;
        JOTFORM_CONTACT = cfg.jotFormId;
        SHARETHIS_PUB = cfg.shareThisId;
        DEFAULT_MAP = cfg.defaultMap;
        MAX_UPLOAD_SIZE = toString cfg.maxUploadSize;
        NETWORK_TIMEOUT_MILLIS = toString cfg.networkTimeout;
        CURRENT_MAP_DATA_VERSION = "a1";
        GEM_PATH = makeSearchPath pkgs.ruby.gemPath rubyClosure;
      } // optionalAttrs (!usesEC2Metadata) {
        S3_KEY_ID = cfg.awsKeyId;
      };
      preStart = ''
        mkdir -m 700 -p /var/lib/mindmup
        if ! test -f /var/lib/mindmup/session.secret; then
            dd if=/dev/urandom count=1 bs=1024 | ${pkgs.utillinux}/bin/hexdump -ve '1/1 "%.2x"' > /var/lib/mindmup/session.secret
            chmod 400 /var/lib/mindmup/session.secret
        fi
      '';
      script = ''
        ${optionalString (!usesEC2Metadata)
          "export S3_SECRET_KEY=$(cat ${cfg.awsSecretKeyFile})"
        }
        export RACK_SESSION_SECRET=$(cat /var/lib/mindmup/session.secret)
        cd ${../.}
        exec ${pkgs.rubyLibs.rack}/bin/rackup config.ru -p ${toString cfg.port}
      '';
      restartTriggers = rubyClosure ++ [ ../. ];
    };
  }) (mkIf (cfg.enable && builtins.lessThan 1024 cfg.port) {
    users.extraUsers.mindmup = {
      description = "Mindmup user";
      group = "mindmup";
    };
    users.extraGroups.mindmup = {};
    systemd.services.mindmup.serviceConfig = {
      USER = "mindmup";
      GROUP = "mindmup";
    };
  }) ];
}
