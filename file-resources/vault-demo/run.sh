#!/bin/bash

# The list of services to run.  Keep this list in the order that they should be started.
declare -a SERVICES=(
  mongodb
  vault
  traefik
)

create_cert_ext() {
  # create the CA extension file
  cat <<EOF > ./certs/test.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=@alt_names

[alt_names]
DNS.1=${HOSTNAME}
DNS.2=localhost
EOF
}

create_certs() {
  if [ ! -d ./certs ] || [ -z "$(ls -A ./certs)" ]; then
    # create the CA extension file
    create_cert_ext
    pushd ./certs || exit
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
    echo "Certs already present in ./certs"
  fi
}

download_sample_data() {
  echo "Downloading sample data"
  if [ ! -f ./mongodb/db/archive/sampledata.archive ]; then
    curl https://atlas-education.s3.amazonaws.com/sampledata.archive -o ./mongodb/db/archive/sampledata.archive
  fi
}

stop() {
  local cat_command="cat"
  for app in "${SERVICES[@]}"; do
    cat_command="${cat_command} ./services/${app}-service.yml"
  done
  ${cat_command} | podman kube down -
  podman network remove data_network
}

start() {
  create_certs
  download_sample_data
  podman network create --ignore data_network
  local cat_command="cat"
  for app in "${SERVICES[@]}"; do
    cat_command="${cat_command} ./services/${app}-service.yml"
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
