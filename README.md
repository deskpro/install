# Installing DeskPRO

This repository contains a set of Ansible playbooks that you can use to install
DeskPRO and its dependencies (MySQL, Elasticsearch) to a single server. These
playbooks can currently be used with:

* Ubuntu 14.04
* Debian 8.1
* CentOS 7

## Using scripts

To run the install, you have two options:

* `curl -s -L https://raw.github.com/DeskPRO/install/master/deskpro-install.sh | sudo bash`
* Clone the repository and run `sudo deskpro-install.sh`

### Minimum requirements

You will need a server with *at least `1GB` of RAM* to properly run DeskPRO and
its dependencies.

Note that the install process above assumes you have both `curl` and `sudo`
installed on your server. If you don't, you can run one of the following
commands to install them:

```bash
apt-get update && apt-get install -y sudo curl # for Debian/Ubuntu hosts
```

```bash
yum install -y sudo curl # for CentOS hosts
```

## DeskPRO Virtual Machines

You can use the links below to download ready made virtual machines with
DeskPRO pre-installed for:

- [Virtual Box](https://s3.eu-central-1.amazonaws.com/deskpro/DeskPRO-Helpdesk-VirtualBox.ova)
- [VMWare](https://s3.eu-central-1.amazonaws.com/deskpro/DeskPRO-Helpdesk-VMWare.zip)
