#!/bin/bash

readonly LDAP_SSL_KEY="/etc/ldap/ssl/ldap.key"
readonly LDAP_SSL_CERT="/etc/ldap/ssl/ldap.crt"

if [[ ! -f "$LDAP_SSL_KEY" ]]; then 
    echo >&2 "the Ldap ssl key file /etc/ldap/ssl/ldap.key is missing" 
    exit 1
fi

if [[ ! -f "$LDAP_SSL_CERT" ]]; then 
    echo >&2 "the Ldap ssl cert file /etc/ldap/ssl/ldap.crt is missing" 
    exit 1
fi

if [[ -z "$SLAPD_DOMAIN" ]]; then
    echo >&2 "Usage: sudo env SLAPD_DOMAIN=<domain> ./sslConfSelfSigned.sh"
    exit 1
fi
    
echo Starting SSL Configuration

apt-get install -y openssl ca-certificates

mkdir /etc/ldap/ssl


make_snakeoil_certificate() {
    echo "Make snakeoil certificate for ${SLAPD_DOMAIN}..."
    openssl req -subj "/CN=${SLAPD_DOMAIN}" \
                -new \
                -newkey rsa:2048 \
                -days 365 \
                -nodes \
                -x509 \
                -keyout ${LDAP_SSL_KEY} \
                -out ${LDAP_SSL_CERT}

    #chmod 600 ${LDAP_SSL_KEY}
    
    chown -R root:openldap /etc/ldap/ssl
    chmod -R o-rwx /etc/ldap/ssl
}


configure_tls() {
    echo "Configure TLS..."
    ldapmodify -Y EXTERNAL -H ldapi:/// -f ./configure/tls.ldif -Q
}


make_snakeoil_certificate

configure_tls

/etc/init.d/slapd restart