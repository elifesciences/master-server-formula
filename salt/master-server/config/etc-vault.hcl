backend "file" {
    path = "/var/lib/vault"
}

disable_mlock=true

# TODO: setup TLS using our wildcard certificate 
# (fallback to no TLS in Vagrant)
listener "tcp" {
    tls_disable = 1
    #tls_cert_file = "/etc/letsencrypt/live/example.com/fullchain.pem"
    #tls_key_file = "/etc/letsencrypt/live/example.com/privkey.pem"
}
