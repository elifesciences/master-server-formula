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

### Testing environment

#### Vagrant

In development/Vagrant, Vault is started in `dev` mode, listening on 8200 via HTTP.

Once Vault is started, the current setup is needed to fully test it:

- retrieve the Vault root token with `sudo journalctl -u vault`
- update `pillar.master_server.vault.access_token` with this value
- comment out the `root` policy for minions in `etc-salt-master.d-vault.conf` and re-provision it to both master and minion
- (optional) add a pillar with `vault kv put secret/projects/master-server/dev number=42` to see it in action

#### EC2

In ci/EC2, Vault is started in production mode, listening on 8200 via HTTPS.

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

Vault is started automatically. The current setup needed to fully test it is:

- init the vault `vault operator init -key-shares=1 -key-threshold=1` 
- store the token in `.vault-token`
- unseal the Vault `vault operator unseal` providing the unseal key just generated
- manually modify `/etc/salt/minion.d/vault.conf` to insert the root token
- `vault kv enable-versioning secret`
- insert a secret with `vault kv put secret/answer number=42`
- smoke test it with `sudo salt-call vault.read_secret secret/data/answer`

Now insert a pillar secret and see it:
- `vault kv put secret/projects/master-server/ci number=42`
- `sudo salt-call pillar.get number`

You can then setup the Salt master too:

- manually modify `/etc/salt/master.d/vault.conf` to insert the root token
- setup a secret with `vault kv put secret/projects/basebox/ci number=43`
- uncomment `root` from `/etc/salt/master.d/vault.conf` to allow the a token to be generated for minions

You can then attach a basebox to it:

- `bldr launch:basebox,pillar-vault` (take care of changing `ec2.master_ip` in its project configuration pointing to the private ip of this `master-server`)
- `bldr ssh:basebox--pillar-vault` will let you access a shell on that instance
- from then you can run `sudo salt-call pillar.get number`

### Vault useful commands

Disables TLS locally:

```
$ export VAULT_ADDR=http://127.0.0.1:8200
```

Initialization is necessary after the first installation. We are using a simple single key setup rather than splitting the key with multiple people:

```
$ vault operator init -key-shares=1 -key-threshold=1 # store the output!
```

Unsealing will be necessary after any reboot or restart of the vault daemon, as data is encrypted at rest:

```
$ vault operator unseal ... # unseal key printed during init
```

Authentication is necessary from the point of view of a user to access a secret:

```
$ vault login
# (insert a valid token)
```

The token can just be the root token generated during initialization, but finer grained tokens can be issued.

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

