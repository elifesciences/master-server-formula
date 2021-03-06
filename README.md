# `master-server` formula

This repository contains instructions for installing and configuring the `master-server` project.

This repository should be structured as any Saltstack formula should, but it 
should also conform to the structure required by the [builder](https://github.com/elifesciences/builder) 
project.

See the eLife [builder example project](https://github.com/elifesciences/builder-example-project)
for a reference on how to integrate with the `builder` project.

[MIT licensed](LICENCE.txt)

## Vault integration

This formula runs a Vault server that the Salt Master can access to populate pillars in addition to the ones provided on the filesystem.

The initial setup leaves around files in `/home/elife/vault-*.log` that contain credentials that the administrator should note down and remove from the filesystem.

A root token is also stored in `~/.vault-token` to allow CLI administration commands to be executed.

A reduced permission tokan is stored in `~/.vault-token.master-server` for the Salt master to use. This token is renewed so that it doesn't expire.

### Testing environment

#### Vagrant

In development/Vagrant, Vault is automatically started, listening on 8200 via HTTP.

#### EC2

In ci/EC2, Vault is automatically started, listening on 8200 via HTTPS.

A test can be performed by creating a masterless `master-server`:

```
bldr masterless.launch:master-server,pillar-vault,standalone,master-server-formula@my_branch
```

`my_branch` is optional, as you can use `master`.

You can apply updates to the branch on the instance with:
```
cd /opt/formulas/master-server-formula
sudo git pull
sudo salt-call state.highstate
```

You can then attach a `basebox` to it to test the minions behavior:

```
vault kv put secret/projects/basebox/ci number=42
# change `ec2.master_ip` in this stack's project configuration,
# pointing to the private ip of this `master-server`
bldr launch:basebox,pillar-vault
bldr ssh:basebox--pillar-vault 
sudo salt-call pillar.get number
```

#### Exploratory testing tasks

Vault is started automatically.

To test Salt's `vault` module, read a secret through Salt:

- insert a secret with `vault kv put secret/answer number=42`
- smoke test it with `sudo salt-call vault.read_secret secret/data/answer`

To test the `elife_vault` module, read a pillar coming from Vault:

```
# 'dev' locally rather than 'ci'
vault kv put secret/projects/master-server/ci number=42
sudo salt-call pillar.get number
```

### Vault useful commands

Unsealing will be necessary after any reboot or restart of the vault daemon, as data is encrypted at rest:

```
$ vault operator unseal ... # unseal key printed during init
```

Authentication is necessary, from the point of view of a user, to access secrets:

```
$ vault login
# (insert a valid token)
```

This will create a `~/.vault-token` file.

The token can just be the root token generated during initialization, but finer grained tokens can be issued.

List all tokens:
```
vault list auth/token/accessors
```

The values returned are accessors, not the secret values of the tokens. They can be used to lookup information about the token:

```
vault token lookup -accessor ACCESSOR
```

Lookup a token by its actual value, if you know it:

```
VAULT_TOKEN=$(cat .vault-token.master-server) vault token lookup
```

Write or read a secret:

```
$ vault kv put secret/hello foo=world
$ vault kv get secret/hello
```

Resetting Vault will lose all stored secrets, but it's useful during local troubleshooting and exemplifies where state is stored:

```
$ sudo su
# systemctl stop vault
# rm -r /var/lib/vault/*
# systemctl start vault
```
