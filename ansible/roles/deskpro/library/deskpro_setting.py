#!/usr/bin/python

ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = '''
---
module: deskpro_setting

short_description: Change or retrieve a setting from Deskpro

version_added: "2.3"

description: |
    Reads or sets a value from the Deskpro settings table. Requires a valid
    Deskpro installation.

    Also requires credentials to the database used by Deskpro, which can be set
    with the `login_`-prefixed options. If not present, this module will try to
    read them off the `config.database.php` file.

    If the setting does not exist, it is created.

options:
    name:
        description: Name of the setting which will be modified/read
        required: yes
    value:
        description: New value of the setting
        required: no

    db:
        description: Name of the database used by Deskpro
        required: no
    login_user:
        description: Username used to access the database
        required: no
    login_password:
        description: Password for the `login_user` user
        required: no
    login_host:
        description: Hostname of the database server
        required: no

    deskpro_path:
        description: |
            Path to the root of the Deskpro installation. Although the module
            will try to find the installation automatically, in some cases it
            may not find it. For these situations, this option can be used.
        required: no

requirements:
    - MySQLdb

notes:
    - Requires the MySQLdb Python package on the remote host.
'''

EXAMPLES = '''
# Change a single setting
- name: Change the `potato.url` setting
  deskpro_setting:
    name: potato.url
    value: https://gotpotato.example.com

# Use with_items to modify multiple settings
- name: Change all these settings
  deskpro_setting:
    name: "{{item.name}}"
    value: "{{item.value}}"
  with_items:
    - name: potato.url
      value: https://gotpotato.example.org
    - name: potato.variety
      value: russet

# Get the value for a specific setting
- name: Get the value for a variable
  deskpro_setting:
    name: potato.flavour
  register: potato_flavour

# Pass in custom database settings
- deskpro_setting:
    name: potato.shape
    login_name: deskpro
    login_user: deskprouser
    login_password: deskpropassword

# Access a helpdesk on a specific location
- deskpro_setting:
    name: potato.color
    deskpro_path: /somewhere/else/deskpro
'''

RETURN = '''
name:
    description: Name of the setting
    returned: always
    type: string
    sample: 'potato.weight'
value:
    description: |
        The current value of the setting (possibly after being modified by the
        original `value` option)
    returned: success
    type: string
    sample: '243 g'
created:
    description: Whether the setting was created by the module
    returned: always
    type: boolean
    sample: True
changed:
    description: Whether the setting was modified or created
    returned: always
    type: boolean
    sample: False
'''

import os
import re

try:
    import MySQLdb
    mysqldb_found = True
except ImportError:
    mysqldb_found = False

from ansible.module_utils.basic import AnsibleModule


class ModuleError(Exception):
    pass


def is_deskpro_install(path):
    build_num_filename = os.path.join(path, 'app/run/build-num.txt')

    try:
        with open(build_num_filename) as build_num_file:
            build_num = build_num_file.read().strip()

        app_dir = os.path.join(path, 'app', build_num)

        if not os.path.isdir(app_dir):
            raise ModuleError(
                'Broken install, build-num.txt does not match app folder'
            )
    except IOError:
        return False

    return True


def get_deskpro_path():
    filename = '/etc/deskpro/install-path'

    try:
        with open(filename) as path_file:
            deskpro_path = path_file.read().strip()
        if is_deskpro_install(deskpro_path):
            return deskpro_path
    except IOError:
        pass

    paths = [
        '/srv/deskpro',
        '/usr/share/deskpro',
        '/usr/share/nginx/deskpro',
        '/usr/share/nginx/html/deskpro',
        '/var/www/deskpro',
        '/var/www/html',
    ]

    for path in paths:
        if is_deskpro_install(path):
            return path

    raise ModuleError('Could not find a Deskpro installation')


def get_database_options(module):
    db_config_filename = os.path.join(
        module.params['deskpro_path'],
        'config/config.database.php',
    )

    with open(db_config_filename) as config_file:
        db_config = config_file.read()

    option_re = re.compile(
        r'''
        (?!(?://|\#)) # Pick a line that doesn't start with a comment
        \s*           # Any spaces are ok
        \$DB_CONFIG   # The literal `$DB_CONFIG`
        \s* \[ \s*    # Opening bracket (with whitespace)
        (?P<q1>'|")   # Opening quote
        (?P<name>.*)  # Name of the option
        (?P=q1)       # Closing quote. Type matches the opening one
        \s* \]        # Closing bracket (with whitespace)
        \s* = \s*     # The equals sign with any whitespace around it
        (?P<q2>'|")   # Opening quote
        (?P<value>.*) # Value of the option
        (?P=q2) \s*   # Closing quote. Type matches the opening one
        ;             # End of statement
        ''',
        re.VERBOSE,
    )

    # names of options inside Deskpro are different that what we're expecting,
    # this is just to translate those names
    key_map = {
        'host': 'login_host',
        'user': 'login_user',
        'password': 'login_password',
        'dbname': 'db',
    }

    options = []
    for match in option_re.finditer(db_config):
        key = key_map[match.group('name')]

        options.append(key)
        module.params[key] = match.group('value')

    if len(options) != len(key_map):
        raise ModuleError(
            'Could not detect database configuration automatically. Please '
            'check the config file for syntax errors or use the `login_*` '
            'options to specify the database credentials manually.'
        )


def check_parameters(module):
    """Check arguments and compute extra parameters.

    Some parameters have default values that need to be computed at runtime,
    and this function will get those values for us as well.
    """

    if module.params['deskpro_path']:
        if not is_deskpro_install(module.params['deskpro_path']):
            raise ModuleError(
                'The `deskpro_path` option should point to a Deskpro '
                ' installation, but it doesn\'t look like there is one at '
                '`{}`'.format(module.params['deskpro_path'])
            )
    else:
        module.params['deskpro_path'] = get_deskpro_path()

    db_options = {
        name: module.params[name]
        for name in ['db', 'login_host', 'login_user', 'login_password']
    }

    if any(db_options.values()):
        if not all(db_options.values()):
            missing = [
                name for name, value in db_options.items() if not value
            ]
            raise ModuleError(
                'You need to use either all or no `login_*` options. The '
                'module is missing the following options: \n\n\t'
                '\n\t'.join(missing)
            )
    else:
        get_database_options(module)


def _read_setting(cursor, name):
    cursor.execute(
        'SELECT value FROM settings WHERE name = %s',
        [name],
    )

    value = cursor.fetchall()
    if len(value) == 1:
        return value[0][0]
    else:
        return None


def write_setting(result, cursor, name, value):
    old_value = _read_setting(cursor, name)

    if old_value == value:
        result['value'] = value
        return

    try:
        if old_value:
            cursor.execute(
                'UPDATE settings SET value = %s WHERE name = %s',
                [value, name],
            )
        else:
            cursor.execute(
                'INSERT INTO settings (name, value) VALUES (%s, %s)',
                [name, value]
            )
        cursor.fetchall()
    except MySQLdb.MySQLError as e:
        raise ModuleError(str(e))

    if old_value is None:
        result['created'] = True
    result['changed'] = True
    result['value'] = _read_setting(cursor, name)


def read_setting(result, cursor, name):
    value = _read_setting(cursor, name)

    if value:
        result['value'] = value
    else:
        raise ModuleError('Setting `{}` does not exist'.format(name))


def mysql_connect(module):
    """Opens a connection to MySQL

    When used as a context manager, the `MySQLdb.Connection` object (which is
    returned by `MySQLdb.connect`) automatically creates a cursor and
    commits/rollbacks the transaction at the end.
    """
    return MySQLdb.connect(
        user=module.params['login_user'],
        passwd=module.params['login_password'],
        host=module.params['login_host'],
        db=module.params['db'],
    )


def main():
    module_args = {
        'name': {
            'required': True,
            'type': 'str',
        },
        'value': {
            'required': False,
            'type': 'str',
            'default': None,
        },
        'db': {
            'required': False,
            'type': 'str',
        },
        'login_user': {
            'required': False,
            'type': 'str',
            'default': None,
        },
        'login_password': {
            'required': False,
            'type': 'str',
            'default': None,
            'no_log': True,
        },
        'login_host': {
            'required': False,
            'type': 'str',
        },
        'deskpro_path': {
            'required': False,
            'type': 'str',
        },
    }

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    result = {
        'name': module.params['name'],
        'changed': False,
        'created': False,
    }

    if not mysqldb_found:
        module.fail_json(msg="The MySQL-python module is required.")

    if not module.check_mode:
        try:
            check_parameters(module)

            with mysql_connect(module) as cursor:
                name = module.params['name']
                value = module.params['value']

                if module.params['value'] is not None:
                    write_setting(result, cursor, name, value)
                else:
                    read_setting(result, cursor, name)

        except ModuleError as e:
            module.fail_json(msg=e.args[0], **result)

    module.exit_json(**result)


if __name__ == '__main__':
    main()
