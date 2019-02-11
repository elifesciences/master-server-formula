import logging

log = logging.getLogger(__name__)

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

