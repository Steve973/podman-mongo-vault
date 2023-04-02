#!/bin/bash

WORK_DIR=/tmp/vault-demo

stop() {
  podman kube down ${WORK_DIR}/services/stack.yml
  podman network remove data_network
}

start() {
  podman network create data_network
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
