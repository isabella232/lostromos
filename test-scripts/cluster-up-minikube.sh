#!/bin/bash

# Copyright (c) 2016-2017 Bitnami
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is taken mostly from https://github.com/bitnami/kubernetes-travis/blob/master/scripts/cluster-up-minikube.sh
# based on https://engineering.bitnami.com/articles/implementing-kubernetes-integration-tests-in-travis.html#minikube-without-vms.
# The kubectl installation is new work we have added, as well as using a prebuilt nsenter image.

# From minikube howto
export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export MINIKUBE_HOME=$HOME
export CHANGE_MINIKUBE_NONE_USER=true
mkdir -p ~/.kube
touch ~/.kube/config

export KUBECONFIG=$HOME/.kube/config
export PATH=${PATH}:${GOPATH:?}/bin

# It's important we are on this version or higher due to issues with kubectl working with <=0.22.2
MINIKUBE_VERSION=v0.22.3
KUBECTL_VERSION=v1.8.2
NSENTER_IMAGE=jpetazzo/nsenter

install_bin() {
    local exe=${1:?}
    test -n "${TRAVIS}" && sudo install -v ${exe} /usr/local/bin || install ${exe} ${GOPATH:?}/bin
}

# Travis ubuntu trusty env doesn't have nsenter, needed for VM-less minikube
# (--vm-driver=none, runs dockerized)
check_or_build_nsenter() {
    which nsenter >/dev/null && return 0
    echo "INFO: Building 'nsenter' ..."
    docker pull $NSENTER_IMAGE
    docker run --rm -v `pwd`:/target $NSENTER_IMAGE
    if [ ! -f ./nsenter ]; then
        echo "ERROR: nsenter pull failed, log:"
        return 1
    fi
    echo "INFO: nsenter build OK, installing ..."
    install_bin ./nsenter
}

check_or_install_minikube() {
    which minikube || {
        wget --no-clobber -O minikube \
            https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64
        install_bin ./minikube
    }
}

install_kubectl() {
    curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
    install_bin ./kubectl
}

# Install nsenter if missing
check_or_build_nsenter
# Install kubectl for use later
install_kubectl
# Install minikube if missing
check_or_install_minikube

MINIKUBE_BIN=$(which minikube)

# Start minikube
sudo -E ${MINIKUBE_BIN} start --vm-driver=none \
    --extra-config=apiserver.Authorization.Mode=RBAC

# Wait til settles
echo "INFO: Waiting for minikube cluster to be ready ..."
typeset -i cnt=120
until kubectl get pod --namespace=kube-system -lapp=kubernetes-dashboard|grep Running ; do
    ((cnt=cnt-1)) || exit 1
    sleep 1
done
exit 0