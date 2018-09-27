import os
import re

from ansible.module_utils.basic import AnsibleModule


PLUGINS_DIR = '/usr/share/elasticsearch/plugins'
PLUGIN_BIN = '/usr/share/elasticsearch/bin/elasticsearch-plugin'


class ModuleError(Exception):
    pass


def get_installed_plugin(name):
    path = os.path.join(PLUGINS_DIR, name, 'plugin-descriptor.properties')
    version_re = re.compile(r'^version=(?P<version>.+)$')

    import sys
    sys.stderr.write(path)
    if not os.path.exists(path):
        return False, None

    with open(path) as fh:
        for line in fh.readlines():
            match = version_re.match(line)
            if match:
                return True, match.group('version')

    raise ModuleError("Could not find plugin {}".format(name))


def parse_plugin_info(plugin):
    maven_re = re.compile(r'^([^:]+):(?P<name>[^:]+):(?P<version>.+)$')
    match = maven_re.match(plugin)
    if match:
        return match.group('name'), match.group('version')

    raise ValueError('Invalid plugin: {}'.format(plugin))


def install_plugin(module):
    cmd = [
        PLUGIN_BIN,
        'install',
        '--batch',
        module.params['plugin'],
    ]

    rc, out, err = module.run_command(cmd)
    if rc != 0:
        raise ModuleError(out)


def main():
    module_args = {
        'plugin': {
            'required': True,
            'type': 'str',
        },
    }

    module = AnsibleModule(
        argument_spec=module_args,
    )

    result = {
        'changed': False,
    }

    plugin = module.params['plugin']

    name, version = parse_plugin_info(plugin)
    present, installed_version = get_installed_plugin(name)

    try:
        if not present:
            install_plugin(module)
            result['changed'] = True
        elif version != installed_version:
            install_plugin(module)
            result['changed'] = True
    except ModuleError as exc:
        module.fail_json(msg=str(exc))

    module.exit_json(**result)


if __name__ == '__main__':
    main()
