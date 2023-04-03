#!/bin/bash

# The list of services to run.  Keep this list in the order that they should be started.
declare -a SERVICES=(
  elasticsearch
  kibana
  mongodb
  vault
  traefik
)

create_cert_ext() {
  # create the CA extension file
  cat <<EOF > @install.dir@/certs/test.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=@alt_names

[alt_names]
DNS.1=${HOSTNAME}
DNS.2=localhost
EOF
}

replace_tokens() {
  local input_file="${1}"
  while IFS="=" read -r key value; do
    sed -e "s,${key},${value},g" -i "${input_file}"
  done < @install.dir@/secrets/users.properties
  chmod 770 "${input_file}"
}

generate_credentials() {
  if [ ! -f @install.dir@/secrets/users.properties ]; then
    traefik_password=$(openssl rand -base64 18)
    htpasswd -nbBC 17 @traefik.dashboard-user.name@ ${traefik_password} > @install.dir@/traefik/credentials.txt
    cat <<EOF > @install.dir@/secrets/users.properties
ELASTIC_ADMIN_USER="@elastic.admin-user.name@"
ELASTIC_ADMIN_PASSWORD="$(openssl rand -base64 18)"
KIBANA_SYSTEM_USER="@kibana.system-user.name@"
KIBANA_SYSTEM_PASSWORD="$(openssl rand -base64 18)"
MONGO_SUPERUSER="@mongo.root-user.name@"
MONGO_SUPERUSER_PASSWORD="$(openssl rand -base64 18)"
MONGO_APPUSER="@mongo.app-user.name@"
MONGO_APPUSER_PASSWORD="$(openssl rand -base64 18)"
VAULT_DEV_ROOT_TOKEN_ID="root"
VAULT_DEV_ROOT_TOKEN="$(openssl rand -base64 18)"
TRAEFIK_DASHBOARD_USER="@traefik.dashboard-user.name@"
TRAEFIK_DASHBOARD_PASSWORD="${traefik_password}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
EOF
    declare -a dirs=(
      @install.dir@/elasticsearch/init-scripts
      @install.dir@/mongodb/init-scripts
      @install.dir@/mongodb/util-scripts
      @install.dir@/vault/util-scripts
      @install.dir@/services
    )
    # Replace username and password tokens in resource files
    for dir in "${dirs[@]}"; do
      for file in "${dir}"/*; do
        replace_tokens "${file}"
      done
    done
    for file in @install.dir@/services/*; do
      replace_tokens "${file}"
    done
  fi
}

create_certs() {
  if [ ! -d @install.dir@/certs ] || [ -z "$(ls -A @install.dir@/certs)" ]; then
    # create the CA extension file
    create_cert_ext
    pushd @install.dir@/certs || exit
    # generate the local CA key
    openssl genrsa -out ./myCA.key 2048
    # generate the local CA cert
    openssl req -x509 -new -nodes -key ./myCA.key -sha384 -days 999 -out ./myCA.pem -subj "/C=XX/ST=Confusion/L=Somewhere/O=example/CN=CertificateAuthority"
    # create certificate signing request
    openssl req -newkey rsa:4096 -nodes -sha384 -keyout ./test.key -out ./test.csr -subj "/C=XX/ST=Confusion/L=Somewhere/OU=first/OU=a002/OU=third/OU=b004/O=example/CN=$(hostname)"
    # process the signing request and sign with the fake CA
    openssl x509 -req -in ./test.csr -CA ./myCA.pem -CAkey ./myCA.key -CAcreateserial -out ./test.crt -days 999 -sha384 -extfile ./test.ext
    # create a p12 keystore
    openssl pkcs12 -export -out ./test.p12 -name "$(hostname)" -inkey ./test.key -in ./test.crt -passout pass:test -passin pass:
    # create a jks truststore
    keytool -import -trustcacerts -noprompt -alias "$(hostname)" -ext san=dns:localhost,ip:127.0.0.1 -file ./myCA.pem -keystore ./truststore.jks -storepass changeit
    # return to previous dir
    popd || exit
  else
    echo "Certs already present in @install.dir@/certs"
  fi
}

download_sample_data() {
  echo "Downloading sample data"
  if [ ! -f @install.dir@/mongodb/db/archive/sampledata.archive ]; then
    curl https://atlas-education.s3.amazonaws.com/sampledata.archive -o @install.dir@/mongodb/db/archive/sampledata.archive
  fi
}

stop() {
  local cat_command="cat"
  for app in "${SERVICES[@]}"; do
    cat_command="${cat_command} @install.dir@/services/${app}-service.yml"
  done
  ${cat_command} | podman kube down -
  podman network remove data_network
}

start() {
  generate_credentials
  create_certs
  download_sample_data
  podman network create --ignore data_network
  local cat_command="cat"
  for app in "${SERVICES[@]}"; do
    cat_command="${cat_command} @install.dir@/services/${app}-service.yml"
  done
  ${cat_command} | podman kube play --replace --network data_network -
}

TEMP=$(getopt -o st --long start,stop -- "$@")
eval set -- "${TEMP}"
case "$1" in
  -s|--start)
    target=start
    ;;
  -t|--stop)
    target=stop
    ;;
  *) echo "Invalid option selected!"
    exit 1
    ;;
esac

eval "${target}"
