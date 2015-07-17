# Installing DeskPRO

This repository contains a set of Ansible playbooks that you can use to install
DeskPRO and its dependencies (MySQL, Elasticsearch) to a single server. These
playbooks can currently be used with:

* Ubuntu 14.04
* Ubuntu 15.04
* Debian 8.1
* CentOS 7

## Using scripts

To run the install, you have two options:

* `curl -s -L https://www.deskpro.com/go/install.sh | sudo bash`
* Clone the repository and run `sudo deskpro-install.sh`

### Minimum requirements

You will need a server with *at least `1GB` of RAM* to properly run DeskPRO and
its dependencies.

You will need root access to the server you want to install DeskPRO into, or be
able to use `sudo`. The install process also assumes you have `curl` installed.
If you don't, you can run one of the commands listed below to install it:

```bash
apt-get update && apt-get install -y curl # for Debian/Ubuntu hosts
```

```bash
yum install -y curl # for CentOS hosts
```

## DeskPRO Virtual Machines

You can use the links below to download ready made virtual machines with
DeskPRO pre-installed for:

- [Virtual Box](https://s3.eu-central-1.amazonaws.com/deskpro/DeskPRO-Helpdesk-VirtualBox.ova)
- [VMWare](https://s3.eu-central-1.amazonaws.com/deskpro/DeskPRO-Helpdesk-VMWare.zip)
