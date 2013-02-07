let
  region = "us-east-1";
  accessKeyId = "mindmup";
  mindmup =
    { resources, ... }:
    { require = [ ./mindmup.nix ];
      ec2.metadata = true;
      deployment.targetEnv = "ec2";
      deployment.ec2.region = region;
      deployment.ec2.keyPair =
        resources.ec2KeyPairs."mindmup-key-pair".name;
      deployment.ec2.instanceProfile =
        resources.iamRoles."mindmup-role".name;
      deployment.ec2.securityGroups = [ "admin" "mindmup" ];

      services.mindmup.s3BucketName =
        resources.s3Buckets."mindmup-bucket".name;
    };
in {
  resources = {
    s3Buckets."mindmup-bucket" = { inherit region accessKeyId; };
    ec2KeyPairs."mindmup-key-pair" = { inherit region accessKeyId; };
    iamRoles."mindmup-role" = { resources, config, ... }: {
      inherit accessKeyId;
      policy = ''{
        "Version":"2008-10-17",
        "Statement": [
          {
            "Action": [
              "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${
                resources.s3Buckets."mindmup-bucket".name}",
              "arn:aws:s3:::${
                resources.s3Buckets."mindmup-bucket".name}/*"
            ]
          }
        ]
      }'';
    };
  };

  backend1 = mindmup;
  backend2 = mindmup;
  proxy =
    { resources, ... }:
    { deployment.targetEnv = "ec2";
      deployment.ec2.region = region;
      deployment.ec2.keyPair =
        resources.ec2KeyPairs."mindmup-key-pair".name;
      deployment.encryptedLinksTo =
        [ "backend1" "backend2" ];
      deployment.ec2.securityGroups = [ "admin" "mindmup" ];
    };
}

