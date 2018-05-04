backend "file" {
    path = "/var/lib/vault"
}

disable_mlock=true

listener "tcp" {
{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
    tls_disable = 0
    tls_cert_file = "/etc/certificates/certificate.crt"
    tls_key_file = "/etc/certificates/privkey.pem"
{% else %}
    tls_disable = 1
{% endif %}
}
