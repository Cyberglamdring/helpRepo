#!/bin/bash
# description: This bash script installing master POD on CentOS
# date:        9/4/2019
# owner:       Hleb Kanonik /Junior System Engineer/ esscyh@gmail.com

# Variables
user="devops"
dockerRepo="https://download.docker.com/linux/centos/docker-ce.repo"
dockerJson=/etc/docker
dockerConf=/etc/sysctl.d/docker.conf
# -----------------------------
# Preparing
# -----------------------------
# 1: First of all install the updates and utilities
yum install udpate -y
yum install -y deltarpm \
               epel-release \
               wget \
               ntp \
               jq \
               net-tools \
               bind-utiles \
               moreutils \
               yum-utils

# 2: Install Docker
# 2.1: work via repository
yum-config-manager --add-repo $dockerRepo
yum-config-manager --enable docker-ce-edge
# 2.2: install docker
yum install docker-ce docker-ce-cli containerd.io

# 2.4: add user to docker group (using witout 'sudo')
if ! [ $(id -u) = 0 ]; then
  usermod -aG docker $user
fi

# 3: Disabling SELinux
getenforce | grep Disabled || setenforce 0
echo "SELINUX=disabled" > /etc/sysconfig/selinux
# 3.1: disabling SWAP
sed -i '/swap/d' /etc/fstab
swapoff --all

# 4: Docker JSON
# 4.1: create config folder
if [[ ! -e $dockerJson ]]; then
  mkdir -p $dockerJson
fi
# 4.2: create config file
if [[ ! -e $dockerJson/daemon.json ]]; then
  touch $dockerJson/daemon.json
fi
tee $dockerJson/daemon.json <<EOF
{
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ]
}
EOF

# 5: Start Docker services
systemctl enable docker
systemctl start docker

docker info | egrep "CGroup Driver"
# 6: Enable passing bridged IPv4 traffice to iptables chains
tee $dockerConf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# -----------------------------
# Kubernetes base installation
# -----------------------------
