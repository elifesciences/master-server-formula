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
    $ vault write secret/projects/elife-xpub/prod smtp.username=foo smtp.password=my_password
The above will result in ``pillar.smtp`` being available as a dictionary with two keys,
 which as for every external pillar will be merged with the rest of the pillars in the Salt master.

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
    env = pillar
    for key in env_key:
        env = env[key]
    vault_key = path.format(project=__grains__['project'], env=env)
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

