#!/bin/bash
# sudo env SLAPD_PASSWORD=<pwd> SLAPD_DOMAIN=<domain> SAMPLE_USER_PASSWORD=<another_pwd> ./prepopulate.sh


if [[ -z "$SLAPD_PASSWORD" ]]; then        
    echo >&2 "Did you forget to add env SLAPD_PASSWORD=... ?"
    exit 1
fi

if [[ -z "$SLAPD_DOMAIN" ]]; then      
    echo >&2 "Did you forget to add env SLAPD_DOMAIN=... ?"
    exit 1
fi 

if [[ -z "$SAMPLE_USER_PASSWORD" ]]; then      
    echo >&2 "Did you forget to add env SAMPLE_USER_PASSWORD=... ?"
    exit 1
fi    
    

echo setting domain

dc_string=""

IFS="."; declare -a dc_parts=($SLAPD_DOMAIN); unset IFS

for dc_part in "${dc_parts[@]}"; do
    dc_string="$dc_string,dc=$dc_part"
done

cp ./prepopulate/basicStructure.template  ./prepopulate/basicStructure.ldif 

sed -i "s/{0}/${dc_string}/g" ./prepopulate/basicStructure.ldif
sed -i "s/{1}/${SLAPD_DOMAIN}/g" ./prepopulate/basicStructure.ldif
sed -i "s/{2}/${SAMPLE_USER_PASSWORD}/g" ./prepopulate/basicStructure.ldif

ldapadd -x -D "cn=admin"${dc_string} -w ${SLAPD_PASSWORD} -H ldap:// -f ./prepopulate/basicStructure.ldif 