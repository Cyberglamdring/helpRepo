#!/bin/bash
# description: This bash script installing master POD on CentOS
# date:        9/4/2019
# owner:       Hleb Kanonik /Junior System Engineer/ esscyh@gmail.com

# Variables
user="devops"
dockerRepo=https://download.docker.com/linux/centos/docker-ce.repo
dockerJson=/etc/docker
dockerConf=/etc/sysctl.d/docker.conf
reposFolder=/etc/yum.repos.d
nodeIp=192.168.56.225
metalLbIp=192.168.56.240/28
flanelLink="https://raw.githubusercontent.com/coreos/flannel/" \
  "62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml"
metalLbLink=https://raw.githubusercontent.com/google/metallb/v0.8.0/manifests/metallb.yaml
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
# 1: Add Kubernetes repository
if [[ ! -e $reposFolder/kubernetes.repo ]]; then
tee $reposFolder/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
fi
# 1.1: installing Kubernetes
yum install -y kubelet kubeadm kubectl kubernetes-cni
systemctl restart docker
systemctl enable kubelet

# Fix for Vagrant kubelet
sed -i "s/\(KUBELET_EXTRA_ARGS=\).*/\1--node-ip=$nodeIp/" /etc/sysconfig/kubelet

# 2: Cluster Initialization
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address $nodeIp \
  --token tqqm17.dq8rsbk5k8tps07y

# 3: Saveing config
if [[ ! -e $HOME/.kube ]]; then
mkdir -p $HOME/.kube
fi

# 4: Deploying POD Network
kubectl apply -f $flanelLink
kubectl patch daemonsets kube-flannel-ds-amd64 -n kube-system --patch='{
  "spec":{
    "template":{
      "spec":{
        "containers":[
          {
            "name": "kube-flannel",
            "args":[
              "--ip-masq",
              "--kube-subnet-mgr",
              "--iface=eth1"
            ]
          }
        ]
      }
    }
  }
}'

# Check POD Network
# kubectl get pods -n kube-system
# kubectl delete pods -n kube-system kube-flannel-ds-amd64-{...}

# 5: Deploying MetalLB
kubectl apply -f $metalLbLink
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $metalLbIp
EOF
