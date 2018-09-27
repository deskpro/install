from random import Random
import string

from ansible.plugins.lookup import LookupBase
import bcrypt


class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):
        username, password = terms

        with open('/etc/deskpro/install-uuid') as fh:
            deskpro_install_uuid = fh.read().strip()

        seed = username + deskpro_install_uuid

        rng = Random(seed)

        charset = string.ascii_letters + string.digits + './'

        salt = '$2a$12$' + ''.join([rng.choice(charset) for _ in range(22)])

        hashed = bcrypt.hashpw(password.encode(), salt)

        return [hashed]
