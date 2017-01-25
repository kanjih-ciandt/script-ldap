#!/bin/bash

# script based on docker file and entrypoint script from https://hub.docker.com/r/dinkel/openldap/

usage_message() {
  echo >&2 "Usage: sudo env SLAPD_PASSWORD=<admin_password> SLAPD_DOMAIN=<domain> ./ldapconfigure.sh"
}


echo Starting OpenLdap installation

apt-get update

OPENLDAP_VERSION=2.4.44 DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y slapd=${OPENLDAP_VERSION}* ldap-utils

echo Copying  basic files
 
mv /etc/ldap /etc/ldap.dist

cp -r ./modules /etc/ldap.dist/modules


# When not limiting the open file descritors limit, the memory consumption of
# slapd is absurdly high. See https://github.com/docker/docker/issues/8231
echo setting ulimit
ulimit -n 8192

set -e

first_run=true

if [[ -f "/var/lib/ldap/DB_CONFIG" ]]; then 
    first_run=false
fi

echo checking password and domain configuration 

if [[ ! -d /etc/ldap/slapd.d ]]; then

    if [[ -z "$SLAPD_PASSWORD" ]]; then
        usage_message
        exit 1
    fi

    if [[ -z "$SLAPD_DOMAIN" ]]; then
        usage_message
        exit 1
    fi

    SLAPD_ORGANIZATION="${SLAPD_DOMAIN}"
    
    echo copying configuration files
    
    if [[ ! -f "/etc/ldap" ]]; then 
        mkdir /etc/ldap
    fi

    cp -r /etc/ldap.dist/* /etc/ldap

    cat <<-EOF | debconf-set-selections
        slapd slapd/no_configuration boolean false
        slapd slapd/password1 password $SLAPD_PASSWORD
        slapd slapd/password2 password $SLAPD_PASSWORD
        slapd shared/organization string $SLAPD_ORGANIZATION
        slapd slapd/domain string $SLAPD_DOMAIN
        slapd slapd/backend select HDB
        slapd slapd/allow_ldap_v2 boolean false
        slapd slapd/purge_database boolean false
        slapd slapd/move_old_database boolean true
EOF

    dpkg-reconfigure -f noninteractive slapd >/dev/null 2>&1
    
    echo setting domain

    dc_string=""

    IFS="."; declare -a dc_parts=($SLAPD_DOMAIN); unset IFS

    for dc_part in "${dc_parts[@]}"; do
        dc_string="$dc_string,dc=$dc_part"
    done

    base_string="BASE ${dc_string:1}"

    sed -i "s/^#BASE.*/${base_string}/g" /etc/ldap/ldap.conf
    
    echo setting password

    if [[ -n "$SLAPD_CONFIG_PASSWORD" ]]; then
        password_hash=`slappasswd -s "${SLAPD_CONFIG_PASSWORD}"`

        sed_safe_password_hash=${password_hash//\//\\\/}

        slapcat -n0 -F /etc/ldap/slapd.d -l /tmp/config.ldif
        sed -i "s/\(olcRootDN: cn=admin,cn=config\)/\1\nolcRootPW: ${sed_safe_password_hash}/g" /tmp/config.ldif
        rm -rf /etc/ldap/slapd.d/*
        slapadd -n0 -F /etc/ldap/slapd.d -l /tmp/config.ldif
        rm /tmp/config.ldif
    fi

    echo setting additional schemas
    
    if [[ -n "$SLAPD_ADDITIONAL_SCHEMAS" ]]; then
        IFS=","; declare -a schemas=($SLAPD_ADDITIONAL_SCHEMAS); unset IFS

        for schema in "${schemas[@]}"; do
            slapadd -n0 -F /etc/ldap/slapd.d -l "/etc/ldap/schema/${schema}.ldif"
        done
    fi

    echo setting  additional modules
    
    if [[ -n "$SLAPD_ADDITIONAL_MODULES" ]]; then
        IFS=","; declare -a modules=($SLAPD_ADDITIONAL_MODULES); unset IFS

        for module in "${modules[@]}"; do
             module_file="/etc/ldap/modules/${module}.ldif"

             if [ "$module" == 'ppolicy' ]; then
                 SLAPD_PPOLICY_DN_PREFIX="${SLAPD_PPOLICY_DN_PREFIX:-cn=default,ou=policies}"

                 sed -i "s/\(olcPPolicyDefault: \)PPOLICY_DN/\1${SLAPD_PPOLICY_DN_PREFIX}$dc_string/g" $module_file
             fi

             slapadd -n0 -F /etc/ldap/slapd.d -l "$module_file"
        done
    fi

    chown -R openldap:openldap /etc/ldap/slapd.d/
else
    slapd_configs_in_env=`env | grep 'SLAPD_'`

    if [ -n "${slapd_configs_in_env:+x}" ]; then
        echo "Info: Container already configured, therefore ignoring SLAPD_xxx environment variables and preseed files"
    fi
fi

chown -R openldap:openldap /var/lib/ldap/ /var/run/slapd/

exec "$@"

 