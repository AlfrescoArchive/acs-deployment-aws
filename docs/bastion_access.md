# How to connect ACS Bastion Host remotely

## Overview

When creating the ACS Cluster on AWS, there was a `RemoteAccessCIDR` parameter value supplied which is the Public IP of the source to allow connect Bastion host using `KeyPairName` ssh-key.

* Obtain `BastionEIP` value from Stack Outputs.  This is the external Public IP of Bastion Host.

* Make sure the permissions of `KeyPairName` used is set to `0600`
```bash
[ec2-user@<BastionHost> ~]$ chmod 0600 my-key-pair.pem
```

* Start SSH connection with the bastion host:
```bash
$ ssh -i my-key-pair.pem ec2-user@<`BastionEIP`>
# To become root user
[ec2-user@<BastionHost> ~]$ sudo -i
```

# Troubleshooting
* If your connections hangs after the ssh command you probably need to authorize the inbound traffic to the bastion for allowing your ip to connect. For more details see [doc](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/authorizing-access-to-an-instance.html)