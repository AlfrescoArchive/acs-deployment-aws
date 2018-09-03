AcsBaseDnsName = attribute('AcsBaseDnsName', description: 'K8s Release')
Bastion = attribute('BastionSubstackName', default: '', description: 'K8s BastionSubStackName')
S3BucketName = attribute('S3BucketName', default: '', description: 'K8s S3BucketName')

# check if alfresco DNS is not available anymore
describe command("acs-deployment-aws/inspec/controls/endpoints.sh https://#{AcsBaseDnsName} 1") do
  its('stdout') { should match /.*DNS is not available - exit.*/ }
  its('exit_status') { should eq 1 }
end

# Check if bastion is deleted
describe command("aws ec2 describe-instances --filters 'Name=tag:Name,Values=#{Bastion}' --query 'Reservations[].Instances[].State.Name' --output text") do
  its('exit_status') { should eq 0 }
  its('stdout') { should eq "terminated\n" }
  its('stderr') { should eq "" }
end

# Check if Bucket is deleted
describe command("aws s3 ls s3://#{S3BucketName}") do
  its('exit_status') { should_not eq 0 }
  its('stdout') { should eq "" }
  its('stderr') { should match /.*NoSuchBucket.*/ }
end

# Check if EKS Cluster is deleted
describe command('kubectl get svc -n kube-system') do
  its('exit_status') { should eq 1 }
  its('stdout') { should eq "" }
  its('stderr') { should match /.*no such host.*/ }
end