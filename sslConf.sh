#!/bin/bash

readonly LDAP_SSL_KEY="/etc/ldap/ssl/ldap.key"
readonly LDAP_SSL_CERT="/etc/ldap/ssl/ldap.crt"

if [[ ! -f "$LDAP_SSL_KEY" ]]; then 
    echo >&2 "the Ldap ssl key file /etc/ldap/ssl/ldap.key is missing" 
    exit 1
fi

if [[ ! -f "$LDAP_SSL_CERT" ]]; then 
    echo >&2 "the Ldap ssl cert file is /etc/ldap/ssl/ldap.crt missing" 
    exit 1
fi

echo Installing dependencies

apt-get install -y openssl ca-certificates

chown -R root:openldap /etc/ldap/ssl
chmod -R o-rwx /etc/ldap/ssl

ldapmodify -Y EXTERNAL -H ldapi:/// -f ./configure/tls.ldif -Q

/etc/init.d/slapd restart