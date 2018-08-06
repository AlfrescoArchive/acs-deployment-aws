# How to connect ACS EKS Worker Node(s) via Bastion

## Overview

The EKS Worker nodes are created inside a private subnet and SSH connections are allowed only from Bastion Host.

* [SSH Bastion](./bastion_access.md)

* On Bastion host, we need to put the `KeyPairName` to access any ACS EKS Worker node.  Also, there are issues using SCP command to copy `KeyPairName` from local host to Bastion host.

* Copy contents of `KeyPairName` file (which is located on your local host)

* Back on Bastion host, create a new file and add contents of `KeyPairName` to it and set correct permissions.
```bash
[ec2-user@<BastionHost> ~]$ vi my-key-pair.pem
[ec2-user@<BastionHost> ~]$ chmod 0600 my-key-pair.pem
```

* From the AWS Console, get Private IP address(es) of the EKS Worker node(s) you want to connect from Bastion
```bash
[ec2-user@<BastionHost> ~]$ ssh -i my-key-pair.pem ec2-user@<PrivateIP>
# To become root user
[ec2-user@<BastionHost> ~]$ sudo -i
```