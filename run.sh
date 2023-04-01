#!/bin/bash

WORK_DIR=/tmp/vault-demo

stop() {
  podman kube down ${WORK_DIR}/services/vault-service.yml
  podman kube down ${WORK_DIR}/services/mongodb-service.yml
  podman kube down ${WORK_DIR}/services/traefik-service.yml
  podman network remove data_network
}

start() {
  podman network create data_network
  podman kube play --network data_network ${WORK_DIR}/services/vault-service.yml
  podman kube play --userns=keep-id:uid=999,gid=999 --network data_network ${WORK_DIR}/services/mongodb-service.yml
  podman kube play --network data_network ${WORK_DIR}/services/traefik-service.yml
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
