'''
eLife Vault Pillar Module

This module allows pillar data to be from Hashicorp Vault.
Below are noted extra configuration required for the pillar module, but the base
configuration of Salt's own ``vault`` module must also be completed.
After the base Vault configuration is created, add the configuration below to
the ext_pillar section in the Salt master configuration.
.. code-block:: yaml
    ext_pillar:
        - elife_vault:
             path: secret/data/projects/{project}/{env}
             env_key: ["elife", "env"]

Each Vault key needs to have all the key-value pairs with the names you
require. The dot ``.`` separates different nesting levels of the values:
.. code-block:: bash
    $ vault write secret/projects/elife-xpub/staging smtp.username=foo smtp.password=my_password
The above will result in ``pillar.smtp`` being available as a dictionary with two keys,
 which as for every external pillar will be merged with the rest of the pillars in the Salt master.

This module assumes a versioned (V2) key value store is setup in Vault:
https://www.vaultproject.io/docs/secrets/kv/kv-v2.html
Notice the example for ``path`` has a ``secret/data/`` prefix which is specific for this store.
'''

import logging

log = logging.getLogger(__name__)

def ext_pillar(minion_id, pillar, path=None, env_key=None):
    '''
    Returns a (usually nested) dictionary of pillars to be merged to the existing ones. 

    ``pillar`` are the existing pillars as a nested dictionary.

    ``path`` is a string template indicating the Vault key to load to find pillars. The template supports ``project`` and ``env`` as placeholders.

    ``env_key`` is a list of strings indicating a path to a pillar key that will be used to deduce the environment.
    '''
    vault_key_context = {'project':__grains__['project']}
    if env_key:
        env = pillar
        for key in env_key:
            env = env[key]
        vault_key_context['env'] = env
    vault_key = path.format(**vault_key_context)
    log.info("Reading vault_key: %s", vault_key)
    vault_value = __salt__['vault.read_secret'](vault_key)
    vault_pillar = {}

    # expand the empty vault_pillar with dictionaries
    # {} => {'elife_xpub': {'smtp': {'username': 'foo'}}}
    for pillar_path in vault_value['data']:
        log.debug("Adding pillar: %s", pillar_path)
        # pillar_branch is a pointer within vault_pillar, 
        # initially pointing to the 'root'
        pillar_branch = vault_pillar
        sections = pillar_path.split(".")
        key = sections[-1]
        del sections[-1]
        for section in sections:
            if section not in pillar_branch:
                pillar_branch[section] = {}
            # updates pointer
            pillar_branch = pillar_branch[section]
        value = vault_value['data'][pillar_path]
        pillar_branch[key] = value
    return vault_pillar

if __name__ == '__main__':
    import unittest
    class VaultExtPillarTest(unittest.TestCase):
        def setUp(self):
            '''
            Stubs dependencies of the ext_pillar function that would be filled
            in by Salt in a real environment
            '''
            global __grains__, __salt__
            __grains__ = {'project': 'elife-xpub'}
            __salt__ = {'vault.read_secret': self._vault_read_secret}
            self._vault_secret = {'default_answer': 42}
        
        def _vault_read_secret(self, vault_key):
            return {'data': self._vault_secret}

        def test_builds_pillar_dictionary(self):
            vault_pillar = ext_pillar('elife-xpub--staging--1', {}, 'secret/my-pillars')
    unittest.main()
