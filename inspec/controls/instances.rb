# Alfresco Enterprise Repository
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

Bastion = attribute('BastionSubstackName', default: '', description: 'K8s BastionSubStackName')
S3BucketName = attribute('S3BucketName', default: '', description: 'K8s S3BucketName')

describe aws_ec2_instance(name: Bastion) do
  it { should be_running }
end

describe aws_s3_bucket(bucket_name: S3BucketName) do
  it { should exist }
  it { should_not be_public }
end