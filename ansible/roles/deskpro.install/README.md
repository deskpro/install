deskpro.install
===============

Creates base files to call a host an "install".

Role Variables
--------------

* `deskpro_install_type`: Type of the install. Is used to tell the log server whether this install was created from the automated installer or VM installer. Defaults to `installer`.

Dependencies
------------

* `deskpro.base`

Example Playbook
----------------

```yml
- hosts: localhost
  roles:
    - role: deskpro.install
      deskpro_install_type: virtual-machine
```
