backend "file" {
    path = "/var/lib/vault"
}

disable_mlock=true

listener "tcp" {
    address = "0.0.0.0:8200"
{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
    tls_disable = false
    tls_cert_file = "/etc/certificates/certificate.crt"
    tls_key_file = "/etc/certificates/privkey.pem"
{% else %}
    tls_disable = true
{% endif %}
}
