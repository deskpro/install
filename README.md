# Installing DeskPRO

This repository contains a set of Ansible playbooks that you can use to install
DeskPRO and its dependencies (PHP, Nginx, MySQL, Elasticsearch) to a single server. These
playbooks can currently be used with:

* Ubuntu 16.04
* Ubuntu 18.04
* Debian Jessie
* Debian Stretch
* CentOS 7

## Using scripts

To run the install, you have two options:

1. Run a command on your server:
    - Ubuntu or Debian:

      ```
      wget -q -O - https://www.deskpro.com/go/install.sh | sudo bash
      ```
    - CentOS:

      ```
      curl -s -L https://www.deskpro.com/go/install.sh | sudo bash
      ```
2. Use git to clone the repository and run `sudo deskpro-install.sh`

    ```
    git clone https://github.com/DeskPRO/install.git
    cd install
    sudo ./deskpro-install.sh
    ```

### Minimum requirements

You will need a server with *at least `1GB` of RAM* to properly run DeskPRO and
its dependencies.

You will need root access to the server you want to install DeskPRO into, or be
able to use `sudo`.

## DeskPRO Virtual Machines

Instead of installing manually, it's also possible to download a virtual
machine with DeskPRO already installed. Check out our [Downloads
page](https://www.deskpro.com/on-premise-download/) for more information.
