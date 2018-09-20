# Alfresco Enterprise Repository
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

S3BucketName = attribute('S3BucketName', default: '', description: 'K8s S3BucketName')

describe command('kubectl get svc -n kube-system') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /kube-dns/ }
  its('stderr') { should eq "" }
end

describe command('kubectl get nodes') do
  its('exit_status') { should eq 0 }
  its('stderr') { should eq "" }
  context "when verifying if an ec2 node exists" do
    its('stdout') { should match /ip-.*ec2\.internal/ }
  end
  context "when verifying if the node is ready" do
    its('stdout') { should match /internal\s*Ready/ }
  end
  context "when verifying if only one node is deployed" do
    its('stdout') { should_not match /.*\n.*\n.*\n/ }
  end
end
