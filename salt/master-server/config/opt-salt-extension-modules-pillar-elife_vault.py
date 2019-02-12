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

# TODO: remove vault_addr
def ext_pillar(minion_id, pillar, path=None, env_key=None, vault_addr=None):
    env = pillar
    for key in env_key:
        env = env[key]
    vault_key = path.format(project=__grains__['project'], env=env)
    log.info("Reading vault_key: %s", vault_key)
    vault_value = __salt__['vault.read_secret'](vault_key)
    vault_pillar = {}
    for pillar_path in vault_value['data']:
        log.debug("Adding pillar: %s", pillar_path)
        pillar_branch = vault_pillar
        sections = pillar_path.split(".")
        key = sections[-1]
        del sections[-1]
        for section in sections:
            if section not in pillar_branch:
                pillar_branch[section] = {}
            pillar_branch = pillar_branch[section]
        value = vault_value['data'][pillar_path]
        pillar_branch[key] = value
    return vault_pillar

