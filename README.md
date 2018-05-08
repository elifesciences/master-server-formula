# `master-server` formula

This repository contains instructions for installing and configuring the `master-server` project.

This repository should be structured as any Saltstack formula should, but it 
should also conform to the structure required by the [builder](https://github.com/elifesciences/builder) 
project.

See the eLife [builder example project](https://github.com/elifesciences/builder-example-project)
for a reference on how to integrate with the `builder` project.

[MIT licensed](LICENCE.txt)

## Vault useful commands

Disables TLS locally:

```
$ export VAULT_ADDR=http://127.0.0.1:8200
```

Initialization is necessary after the first installation. We are  using a simple single key setup rather than splitting the key with multiple people:

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
