#!/usr/bin/python

ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = '''
---
module: deskpro_install_log

short_description: Send log information about the Deskpro install

version_added: "2.3"

description: |
    Send log information to the Deskpro log server. The information sent varies
    depending on the desired action.

options:
    action:
        description: |
            Action to perform. A `start` is usually required as the first
            action before the other ones have any meaning.
        required: yes
        choices:
            - start
            - success
            - failure
            - log
    duration:
        description: |
            Time spent, in seconds,  since the `start` action was used. Only
            accepted for `success`, `failure`, and `log` actions.
        required: no
    summary:
        description: |
            A short description of the failure. Used for the `failure` action.
        required: no
    path:
        description: |
            Path to a log file to be uploaded. Used with the `log` action.
        required: no
    type:
        description: |
            Type of the install. Used by the log server to isolate issues.
        required: yes
        choices:
            - installer
            - virtual-machine
'''

EXAMPLES = '''
# Register the start of the install
- name: Save start time
  set_fact:
    deskpro_install_start: {{ansible_date_time.epoch}}

- name: Log install start
  deskpro_install_log:
    action: start
    type: installer

# Signal a successful installation
- name: Log install success
  deskpro_install_log:
    action: success
    duration: "{{ansible_date_time.epoch - deskpro_install_start}}"
    type: installer

# Signal a failure during the installation
- name: Log install failure
  deskpro_install_log:
    action: failure
    duration: "{{ansible_date_time.epoch - deskpro_install_start}}"
    summary: "{{item.splitlines()[0][:100]}}"
    type: installer
  with_file: /path/to/log/file

# Upload failure logs
- name: Upload logs
  deskpro_install_log:
    action: log
    path: /path/to/log/file
    type: installer
'''

RETURN = ''' # '''

import uuid

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.facts import ansible_facts
from ansible.module_utils.urls import fetch_url


class ModuleError(Exception):
    pass


def get_install_uuid():
    filename = '/etc/deskpro/install-uuid'

    try:
        with open(filename) as uuid_file:
            install_uuid = uuid_file.read().strip()
            try:
                uuid.UUID(install_uuid)
                return install_uuid
            except ValueError:
                raise ModuleError('Format of UUID file is incorrect')
    except IOError:
        raise ModuleError('UUID file is missing')


def log_failure(module):
    post_log(
        module,
        {
            'duration': module.params['duration'],
            'summary': module.params['summary'],
        },
    )


def log_start(module):
    facts = ansible_facts(module, ['hardware', 'virtual'])
    post_log(
        module,
        {
            'os': {
                'name': facts['ansible_lsb']['description'],
                'virtualization_role': facts['ansible_virtualization_role'],
                'virtualization_type': facts['ansible_virtualization_type'],
            },
            'hardware': {
                'cpus': facts['ansible_processor_count'],
                'memory': facts['ansible_memtotal_mb'],
            },
        },
    )


def log_success(module):
    post_log(
        module,
        {
            'duration': module.params['duration'],
        },
    )


def log_upload(module):
    with open(module.params['path']) as logfile:
        log = logfile.read()

    post_log(module, log)


def post_log(module, data):
    url = 'http://app-stats.deskpro-service.com/installer/{}/{}/{}'.format(
        module.params['type'], module.params['uuid'], module.params['action'],
    )
    headers = {}

    if isinstance(data, dict):
        data = module.jsonify(data)
        headers = {
            'Content-Type': 'application/json',
        }

    fetch_url(module, url, data, headers, 'POST')


def require_argument(module, name):
    if not module.params[name]:
        raise ModuleError(
            'Action `{}` requires the `{}` argument'.format(
                module.params['action'],
                name,
            )
        )


def main():
    module_args = {
        'action': {
            'required': True,
            'type': 'str',
            'choices': ['start', 'success', 'failure', 'log'],
        },
        'duration': {
            'required': False,
            'type': 'float',
            'default': None,
        },
        'summary': {
            'required': False,
            'type': 'str',
            'default': '',
        },
        'path': {
            'required': False,
            'type': 'str',
            'default': None,
        },
        'type': {
            'required': True,
            'type': 'str',
            'choices': ['installer', 'virtual-machine'],
        }
    }

    result = {
        'changed': False,
    }

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    if module.check_mode:
        return result

    module.params['uuid'] = get_install_uuid()

    if module.params['action'] == 'start':
        log_start(module)
    elif module.params['action'] == 'success':
        require_argument(module, 'duration')
        log_success(module)
    elif module.params['action'] == 'failure':
        require_argument(module, 'duration')
        require_argument(module, 'summary')
        log_failure(module)
    elif module.params['action'] == 'log':
        require_argument(module, 'path')
        log_upload(module)
    else:
        module.fail_json(
            msg='Invalid action `{}`'.format(module.params['action']),
            **result
        )

    module.exit_json(**result)


if __name__ == '__main__':
    main()
