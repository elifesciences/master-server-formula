backend "file" {
    path = "/var/lib/vault"
}

disable_mlock=true

listener "tcp" {
    address = "127.0.0.1:8201"
    tls_disable = true
}

# https://hostname.org:8200/ui/
ui = true
