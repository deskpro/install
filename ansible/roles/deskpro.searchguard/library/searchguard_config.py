import requests
import subprocess

from ansible.module_utils.basic import AnsibleModule
import urllib3
import urllib3.contrib.pyopenssl


ES_ROOT = '/usr/share/elasticsearch'


def get_searchguard_config(module):
    url = 'https://localhost:9200/searchguard/{}/0/_source'.format(
        module.params['type'],
    )

    response = requests.get(
        url,
        verify=module.params['cacert'],
        cert=(
            module.params['cert'],
            module.params['key'],
        ),
    )

    if response.status_code != 200:
        return ''

    return response.json()[module.params['type']]


def apply_searchguard_config(module):
    command = [
        'bash',
        '/usr/share/elasticsearch/plugins/search-guard-5/tools/sgadmin.sh',
        '-cacert', module.params['cacert'],
        '-cert', module.params['cert'],
        '-key', module.params['key'],
        '--file', module.params['path'],
        '--type', module.params['type'],
    ]

    subprocess.check_output(
        command,
        stderr=subprocess.PIPE,
    )


def main():
    module_args = {
        'path': {
            'required': True,
            'type': 'str',
        },
        'type': {
            'required': True,
            'type': 'str',
            'choices': [
                'config',
                'roles',
                'rolesmapping',
                'internalusers',
                'actiongroups',
            ],
        },
        'cert': {
            'required': True,
            'type': 'path',
        },
        'key': {
            'required': True,
            'type': 'path',
        },
        'cacert': {
            'required': True,
            'type': 'path',
        },
    }

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True,
    )

    result = {
        'changed': False,
    }

    old_config = get_searchguard_config(module)
    apply_searchguard_config(module)
    new_config = get_searchguard_config(module)

    if old_config != new_config:
        result['changed'] = True

    module.exit_json(**result)


if __name__ == '__main__':
    urllib3.contrib.pyopenssl.inject_into_urllib3()
    main()
