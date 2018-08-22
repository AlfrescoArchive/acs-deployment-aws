K8sNamespace = attribute('K8sNamespace', default: 'acs-deployment', description: 'K8s Namespace')
AcsReleaseName = attribute('AcsReleaseName', default: 'enterprise', description: 'K8s Release')

# Custom inspec checks to determine various component status

# Check Tiller status 
describe command("kubectl get pods -l name=tiller --namespace kube-system -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running/ }
  its('stderr') { should eq "" }
end

# Check nginx-ingress controller pod status 
describe command("kubectl get pods -l app=nginx-ingress,component=controller --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running/ }
  its('stderr') { should eq "" }
end

# Check nginx-ingress default backend pod status 
describe command("kubectl get pods -l app=nginx-ingress,component=default-backend --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running/ }
  its('stderr') { should eq "" }
end

# Check ACS Repository pod status 
describe command("kubectl get pods -l release=#{AcsReleaseName},component=repository --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running Running/ }
  its('stderr') { should eq "" }
end

# Check Share pod status 
describe command("kubectl get pods -l release=#{AcsReleaseName},component=share --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running/ }
  its('stderr') { should eq "" }
end

# Check Transformers pod status 
describe command("kubectl get pods -l release=#{AcsReleaseName},component=transformers --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running Running Running Running Running/ }
  its('stderr') { should eq "" }
end

# Check Solr pod status 
describe command("kubectl get pods -l app=#{AcsReleaseName}-alfresco-search-solr,release=#{AcsReleaseName} --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running/ }
  its('stderr') { should eq "" }
end

# Check Postgresql pod status 
describe command("kubectl get pods -l app=#{AcsReleaseName}-postgresql-acs --namespace #{K8sNamespace} -o jsonpath={.items..phase}") do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /Running/ }
  its('stderr') { should eq "" }
end
