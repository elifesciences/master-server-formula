import logging

log = logging.getLogger(__name__)

def ext_pillar(minion_id, pillar, path=None, env_key=None, vault_addr=None):
    log.critical("pillar: %s", type(pillar))
    log.critical("elife_vault: %s %s", path, vault_addr)
    log.critical("grains project: %s", __grains__['project'])
    env = pillar
    for key in env_key:
        env = env[key]
    log.critical("env: %s", env)
    vault_key = path.format(project=__grains__['project'], env=env)
    log.critical("vault_key: %s", vault_key)
    vault_value = __salt__['vault.read_secret'](vault_key)
    log.critical("vault_value: %s", vault_value)
    vault_pillar = {}
    for pillar_path in vault_value['data']:
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
    log.critical("vault_pillar: %s", vault_pillar)
    return vault_pillar

