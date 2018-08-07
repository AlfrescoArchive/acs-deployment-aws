describe command('kubectl get svc') do
  its('exit_status') { should eq 0 }
end