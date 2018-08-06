# EKS Cluster remote access

## Overview

Once the EKS Cluster is created, only the worker nodes can access it.  In order to access the cluster remotely (ex: local host), below are the instructions to setup.

1. [Prerequisites](../README.md#Prerequisites)

2. [SSH Bastion](./bastion_access.md)

3. To get EKS cluster information
```bash
[ec2-user@ip-10-0-153-59 ~]$ kubectl cluster-info
Kubernetes master is running at https://4DB60B3D8DE3418CB349578ADFC4DE2D.sk1.us-east-1.eks.amazonaws.com

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

4. To get EKS Worker node(s) information
```bash
[ec2-user@ip-10-0-153-59 ~]$ kubectl get node
NAME                         STATUS    ROLES     AGE       VERSION
ip-10-0-4-105.ec2.internal   Ready     <none>    27m       v1.10.3
```

5. To get `kubeconfig` file information
```bash
[ec2-user@ip-10-0-157-55 ~]$ cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    server: https://1BCB31ACB5EE0917FC239263D2783800.sk1.us-east-1.eks.amazonaws.com
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRFNE1EY3pNREUwTkRjME5Wb1hEVEk0TURjeU56RTBORGMwTlZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTnkwCkl6SEpvRjI2QUJSVzQzZ3QyQ2NvTXJ4dTNqUTVQNldPTE1nb2tpNG9EZ0JRQVFQcTk2dDM0TWUrd0x2dzV0MUcKbFUwc1NkNkZydmVtWHRvZGxvNCtxVjZ0NDdBQjhhcnUwQ0VVcG9ab3JlOFVpL0RBbWEwaTlxWW53b1hqZ1JCMgpOTU5WckZFdGFDcUpPZ2VJcnBLQ1hXOUhwUnhGWnFIK0MrMXB5bElBUkk5ZGRyVjF2ZUg2c1h3NFd6UUtraDlnCnVQMWdJdkRaVFhTMC9TQUtSS0dOTXltZ0huSHdTYXBHWFFFMlgwU0hVeGx1NWhOMnFWWUY5Zm5WZnZDa2dMWC8Kb1E5NVZISkd4VTNPbEJndTNvc2ZOWFZhbFI0VkRNekprcFduVlczSzNKM3cxMzVBYi92Z1B3a1M1TkNKdkNaWgpSYng2NEd2M2h0WEFBZmVZbHQ4Q0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFGdGhYQ0prOFY0bktyeFdWbGpod2g1SUdVT0cKSEdNaGF3bEFVMzRCUE83MXNMSkp3K3NmYThxN3FaODdwUkNyWDYwS3NFZG5TL2lNckdPZ2o2OFFKOVhIaUNMRQpqdFNvL1gwUU9pUnVQNnV0VVMxbFhadGlyS2xNMXEvTVFFSFk1V1lQSkwxcWVRNitlQm96YUJnNGpaMU5DSExXCmVPT0ZQUG0vaHkySjJKVFBVOTUyVTVScmxWWmw1YmtiK0VGaitQTE5ONmtJTjRqQ1VPY05qTFM0cVFCTWlUV2IKRXA4TUVKSHBqeXZ4NC8waVFPWCtmVW94Mk1oVDVQODU1bFRDb01oNUg5Y3RBM0VieGdqRDkwNThRZ1lpL1VJNgpWUjdjUVZpMk8yOHFXa2ppNXFyVWE1SzlUbWo1UUZCT1RHQVNHQTJuMUdDRVE4V3U0VlFQWGNQODZHaz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - token
        - -i
        - repo-3691-1-BastionAndEksClusterStack-17IRSLL06VD1U-cluster
```

6. If `kubectl` displays EKS Cluster / Workers information, then you may proceed with next steps

7. Edit `kube-system` config map for `aws-auth`
```bash
[ec2-user@ip-10-0-153-59 ~]$ kubectl edit -n kube-system configmap/aws-auth
```

It should have contents like below:
```
data:
  mapRoles: |
    - rolearn: arn:aws:iam::586394462691:role/repo-3691-1-BastionAndEksClusterS-NodeInstanceRole-1K2YRJBZTMCDH
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
```

* To allow external access to EKS Cluster, the AWS IAM user name and Arn is required.  Add entries like below in above `aws-auth` configmap
```
data:
  mapRoles: |
    - rolearn: arn:aws:iam::586394462691:role/repo-3691-1-BastionAndEksClusterS-NodeInstanceRole-1K2YRJBZTMCDH
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: arn:aws:iam::<AccountId>:user/<IamUser>
      username: admin
      groups:
        - system:masters
```

8. Save & exit the file.  At this point, the provided IAM user has been granted access to the EKS Cluster.

9. On your local machine, create a `kubeconfig` file in your home directory and copy the contents of Step 5 in it and save it.

10. Install `aws-iam-authenticator` binary on your local host following AWS Documentation at https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html and look for `To install aws-iam-authenticator for Amazon EKS` section.

11. Test `aws-iam-authenticator` is working as expected.
```bash
$ aws-iam-authenticator help
A tool to authenticate to Kubernetes using AWS IAM credentials
apiVersion: v1

Usage:
  aws-iam-authenticator [command]

Available Commands:
  help        Help about any command
  init        Pre-generate certificate, private key, and kubeconfig files for the server.
  server      Run a webhook validation server suitable that validates tokens using AWS IAM
  token       Authenticate using AWS IAM and get token for Kubernetes
  verify      Verify a token for debugging purpose

Flags:
  -i, --cluster-id ID     Specify the cluster ID, a unique-per-cluster identifier for your aws-iam-authenticator installation.
  -c, --config filename   Load configuration from filename
  -h, --help              help for aws-iam-authenticator

Use "aws-iam-authenticator [command] --help" for more information about a command.
```

12.  Try running Step 2 and 3 commands from your local host.  If you get exactly the same output then you have successfully setup access to EKS Cluster.