{ region ? "us-east-1" }:
let
  mindmup = { resources, ... }: {
    deployment = {
      targetEnv = "ec2";
      ec2 = {
        inherit region;
        accessKeyId = "mindmup";
        keyPair = resources.ec2KeyPairs."mindmup-key-pair".name;
        instanceProfile = resources.iamRoles."mindmup-role".name;
      };
    };
  };
in {
  resources = {
    s3Buckets."mindmup-bucket" = {
      inherit region;
      accessKeyId = "mindmup";
    };
    ec2KeyPairs."mindmup-key-pair" = {
      inherit region;
      accessKeyId = "mindmup";
    };
    iamRoles."mindmup-role" = { resources, config, ... }: {
      accessKeyId = "mindmup";
      policy = ''{
        "Version":"2008-10-17",
        "Statement": [
          {
            "Action": [
              "s3:ListAllMyBuckets"
            ],
            "Effect": "Allow",
            "Resource": ["arn:aws:s3:::*"]
          },
          {
            "Action": [
              "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${resources.s3Buckets."mindmup-bucket".name}",
              "arn:aws:s3:::${resources.s3Buckets."mindmup-bucket".name}/*"
            ]
          }
        ]
      }'';
    };
  };
  backend1 = mindmup;
  backend2 = mindmup;
  proxy = { resources, ... }: {
    deployment = {
      targetEnv = "ec2";
      ec2 = {
        inherit region;
        accessKeyId = "mindmup";
        keyPair = resources.ec2KeyPairs."mindmup-key-pair".name;
      };
    };
  };
}
