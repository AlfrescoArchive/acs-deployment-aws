bastion = attribute('BastionSubstackName', default: '', description: 'K8s BastionSubStackName')

describe aws_ec2_instance(name: bastion) do
  it { should be_running }
end