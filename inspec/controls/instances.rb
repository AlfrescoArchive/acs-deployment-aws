bastion = attribute('BastionSubStackName', default: '', description: 'K8s BastionSubStackName')

describe aws_ec2_instance(name: bastion + '-k8s-bastion') do
  it { should be_running }
end