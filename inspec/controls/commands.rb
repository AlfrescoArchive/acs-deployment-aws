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

describe command("aws s3 cp outputs.yaml s3://#{S3BucketName}/outputs.yaml --cli-read-timeout 3 --cli-connect-timeout 3") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /outputs.yaml/ }
  its('stderr') { should eq "" }
end

describe command("sleep 2; aws s3 ls s3://#{S3BucketName} --cli-read-timeout 3 --cli-connect-timeout 3") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /outputs.yaml/ }
  its('stderr') { should eq "" }
end

describe command("aws s3 rm s3://#{S3BucketName}/outputs.yaml --cli-read-timeout 3 --cli-connect-timeout 3") do
  its('exit_status') { should eq 0 }
  its('stderr') { should eq "" }
end

describe command("sleep 3; aws s3 ls s3://#{S3BucketName} --cli-read-timeout 3 --cli-connect-timeout 3") do
  its('exit_status') { should eq 0 }
  its('stdout') { should_not match /outputs.yaml/ }
  its('stderr') { should eq "" }
end
