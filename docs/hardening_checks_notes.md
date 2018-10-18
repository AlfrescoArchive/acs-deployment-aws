# Hardening Notes

**Run kubebench on the master**
*  DOES NOT WORK! In EKS we don’t have access to the master node; the pod simply never gets scheduled as the scheduler can’t find a node that matches that requirement, but this is the command:
```
kubectl run --rm -i -t kube-bench-master --image=aquasec/kube-bench:latest --restart=Never --overrides="{ \"apiVersion\": \"v1\", \"spec\": { \"hostPID\": true, \"nodeSelector\":{ \"kubernetes.io/role\": \"master\" }, \"tolerations\":[ { \"key\": \"node-role.kubernetes.io/master\", \"operator\": \"Exists\", \"effect\": \"NoSchedule\" } ] } }" -- master --version 1.8
```

**Run kubebench on the worker nodes**

* From bastion
```
kubectl run --rm -i -t kube-bench-node --image=aquasec/kube-bench:latest --restart=Never --overrides="{ \"apiVersion\": \"v1\", \"spec\": { \"hostPID\": true } }" -- node --version 1.8
```

* From the worker nodes:
```
docker run --rm -v `pwd`:/host aquasec/kube-bench:latest install
./kube-bench node
```

NOTE: using kubectl results are more comprehensive than running it from the worker nodes.
