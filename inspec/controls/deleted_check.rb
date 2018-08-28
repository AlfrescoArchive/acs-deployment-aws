K8sNamespace = attribute('K8sNamespace', description: 'K8s Namespace')
AcsBaseDnsName = attribute('AcsBaseDnsName', description: 'K8s Release')


# Endpoints check

describe command("acs-deployment-aws/inspec/controls/endpoints.sh https://#{AcsBaseDnsName} 1") do
  its('stdout') { should match /DNS is not available - exit/ }
  its('exit_status') { should eq 1 }
end

describe http("https://#{AcsBaseDnsName}/share/page", open_timeout: 60, read_timeout: 60, ssl_verify: true) do
  its('status') { should eq 404 }
end