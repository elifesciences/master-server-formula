'''
elife_vault Pillar Module

This module allows pillar data to be populated from Hashicorp Vault.
Below are noted configuration options required for this external pillar module;
it depends on Salt's own ``vault`` module that must also be configured.
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

**This module assumes a versioned (V2) key value store is setup in Vault**:
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
    try:
        vault_key = _render_vault_key(pillar, path, env_key)
    except KeyError as e:
        log.warn("Stack does not have a 'project' grain': %s", e)
        return {}
    log.info("Reading vault_key: %s", vault_key)
    try:
        vault_value = __salt__['vault.read_secret'](vault_key)
    except Exception as e:
        log.warn("Error accessing Vault (%s): %s", type(e), e.message)
        return {}

    return _expand_vault_pillar(vault_value['data'])

def _render_vault_key(pillar, path, env_key=None):
    vault_key_context = {'project':__grains__['project']}
    if env_key:
        env = pillar
        for key in env_key:
            env = env[key]
        vault_key_context['env'] = env
    return path.format(**vault_key_context)

def _expand_vault_pillar(data):
    '''
    Expands the empty vault_pillar with dictionaries
    # {} => {'elife_xpub': {'smtp': {'username': 'foo'}}}
    '''

    vault_pillar = {}
    def _find_branch_and_key(pillar_path):
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
        return pillar_branch, key
        
    for pillar_path in data:
        log.debug("Adding pillar: %s", pillar_path)
        pillar_branch, key = _find_branch_and_key(pillar_path)
        pillar_branch[key] = data[pillar_path]

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
            self._vault_exception = None
            self._vault_key_read = None
        
        def _vault_read_secret(self, vault_key):
            if self._vault_exception:
                raise self._vault_exception
            self._vault_key_read = vault_key
            return {'data': self._vault_secret}

        def test_builds_pillar_dictionary(self):
            vault_pillar = ext_pillar('elife-xpub--staging--1', {}, path='secret/my-pillars')
            self.assertEqual(vault_pillar, {'default_answer': 42})

        def test_builds_nested_pillar_dictionary(self):
            self._vault_secret = {'smtp.username': 'foo', 'smtp.password': 'bar', 'orcid.secret': 'baz'}
            vault_pillar = ext_pillar('elife-xpub--staging--1', {}, path='secret/my-pillars')
            self.assertEqual(vault_pillar, {'smtp': {'username': 'foo', 'password': 'bar'}, 'orcid': {'secret': 'baz'}})

        def test_renders_a_dynamic_vault_key(self):
            ext_pillar(
                'elife-xpub--staging--1',
                {
                    'elife': {'env': 'staging'}
                },
                path='secret/my-pillars/{project}/{env}',
                env_key=['elife', 'env']
            )
            self.assertEqual(self._vault_key_read, 'secret/my-pillars/elife-xpub/staging')

        def test_exceptions_are_caught_to_avoid_breaking_highstate(self):
            self._vault_exception = Exception("Cannot read missing key")
            vault_pillar = ext_pillar('elife-xpub--staging--1', {}, path='secret/my-pillars')
            self.assertEqual(vault_pillar, {})
            

    unittest.main()
