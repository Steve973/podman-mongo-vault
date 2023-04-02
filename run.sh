#!/bin/bash

WORK_DIR=/tmp/vault-demo

copy_file_resources() {
  echo "Creating or updating deployment resources"
  mkdir -p ${WORK_DIR}
  rsync -av file-resources/vault-demo/* ${WORK_DIR} --exclude=.deleteme
  cat ./file-resources/services/mongodb-service.yml \
    ./file-resources/services/vault-service.yml \
    ./file-resources/services/traefik-service.yml > ${WORK_DIR}/services/stack.yml
}

create_cert_ext() {
  # create the CA extension file
  cat <<EOF > "${WORK_DIR}/certs/test.ext"
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
  if [ ! -d "${WORK_DIR}/certs" ] || [ -z "$(ls -A ${WORK_DIR}/certs)" ]; then
    # create the CA extension file
    create_cert_ext
    pushd "${WORK_DIR}/certs"
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
    popd
  else
    echo "Certs already present in ${WORK_DIR}/certs"
  fi
}

download_sample_data() {
  echo "Downloading sample data"
  curl https://atlas-education.s3.amazonaws.com/sampledata.archive -o ${WORK_DIR}/mongodb/db/archive/sampledata.archive
}

init() {
  if [ ! -d "${WORK_DIR}" ]; then
    copy_file_resources
    create_certs
    download_sample_data
  else
    copy_file_resources
  fi
}

stop() {
  podman kube down ${WORK_DIR}/services/stack.yml
  podman network remove data_network
}

start() {
  init
  podman network create --ignore data_network
  podman kube play --network data_network ${WORK_DIR}/services/stack.yml
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
