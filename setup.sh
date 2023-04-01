#!/bin/bash

WORK_DIR=/tmp/vault-demo

copy_file_resources() {
  mkdir -p ${WORK_DIR}
  cp -r file-resources/vault-demo/* ${WORK_DIR}
  find ${WORK_DIR} -type f -name .deleteme -exec rm {} \;
}

create_certs() {
  if [ ! -d "${WORK_DIR}/certs" ] || [ -z "$(ls -A ${WORK_DIR}/certs)" ]; then
    # create the CA extension file
    envsubst < ./file-resources/setup/cert-ext.txt > "${WORK_DIR}/certs/test.ext"
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
  fi
}

create_secrets() {
  declare -A secrets=(
    [test-crt]="${WORK_DIR}"/certs/test.crt
    [test-key]="${WORK_DIR}"/certs/test.key
    [trust-pem]="${WORK_DIR}"/certs/myCA.pem
  )
  for secret_name in "${!secrets[@]}"; do
    podman secret ls --format "{{.Name}}" | grep "${secret_name}" || \
    podman secret create --driver=file "${secret_name}" "${secrets[${secret_name}]}"
  done
}

init_mongodb() {
  declare -a mongo_script_dirs=(
    ${WORK_DIR}/mongodb/init-scripts
    ${WORK_DIR}/mongodb/util-scripts
  )

  echo "Downloading sample data"
  curl https://atlas-education.s3.amazonaws.com/sampledata.archive -o ${WORK_DIR}/mongodb/archive/sampledata.archive

  echo "Starting MongoDB for provisioning"
  podman kube play --userns=keep-id:uid=999,gid=999 ${WORK_DIR}/services/mongodb-service.yml

  echo "Waiting for initialization"
  RESTARTED="command replSetGetStatus requires authentication"
  STATUS=STARTING
  while ! [[ "${STATUS}" =~ ${RESTARTED} ]]
  do
    STATUS=$(podman exec -it mongodb-pod-mongodb mongosh --quiet --eval 'rs.status()')
    sleep 2
  done

  echo "Waiting for MongoDB restart"
  STATUS=STARTING
  while ! [[ "${STATUS}" =~ ^.*\(healthy\)$ ]]
  do
    STATUS=$(podman ps --filter name=mongodb-pod-mongodb --format '{{ .Status }}')
    sleep 2
  done

  echo "Running post-init replica set initiation"
  podman exec -it mongodb-pod-mongodb /local/bin/post-init.sh

  echo "MongoDB initialization complete"
}

init_traefik() {
  echo "Creating Traefik dashboard credentials"
  #  Do something here to create the dashboard credentials
}

systemctl --user status podman.socket &>/dev/null || systemctl --user start podman.socket
copy_file_resources
create_certs
create_secrets
init_mongodb
init_traefik
echo "Setup complete"
