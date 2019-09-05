#!/bin/bash
# description: This bash script installing master POD on CentOS
# date:        9/4/2019
# owner:       Hleb Kanonik /Junior System Engineer/ esscyh@gmail.com

# Variables
user=vagrant
dockerRepo=https://download.docker.com/linux/centos/docker-ce.repo
dockerJson=/etc/docker
dockerConf=/etc/sysctl.d/docker.conf
reposFolder=/etc/yum.repos.d
# nodeIp = ipaddres VM
nodeIp=172.17.51.36
metalLbIp=172.17.51.240/28
flanelLink=https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml
metalLbLink=https://raw.githubusercontent.com/google/metallb/v0.8.0/manifests/metallb.yaml
ingMandatory=https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
ingCloudGeneric=https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/cloud-generic.yaml
ingServiceNodeport=https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/service-nodeport.yaml

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
  yum-utils \
  git \
  device-mapper-persistent-data \
  lvm2

systemctl start ntpd
systemctl enable ntpd

# 2: Install Docker
# 2.1: work via repository
yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

# 2.2: install docker
yum install -y docker-ce-18.09.8
# yum install -y docker-ce docker-ce-cli containerd.io

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
systemctl enable docker.service
systemctl start docker.service

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
systemctl restart docker.service
systemctl enable kubelet

# Fix for Vagrant kubelet
sed -i "s/\(KUBELET_EXTRA_ARGS=\).*/\1--node-ip=$nodeIp/" /etc/sysconfig/kubelet

# 2: Cluster Initialization
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address $nodeIp

# kubeadm join 172.17.51.36:6443 --token 0izskl.x1paurjk6c6ovwvx \
#    --discovery-token-ca-cert-hash sha256:d7ecf99ed6e4d39ce0e3591fad4be23a292e353cff9f510f0280130decd32b7e


# 3: Saveing config
# also reply thsi step in you local PC
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

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

# 6: Nginx Ingress Controller
kubectl apply -f $ingMandatory
# Create a service
kubectl apply -f $ingCloudGeneric
kubectl apply -f $ingServiceNodeport

cd /tmp/
git clone https://github.com/nginxinc/kubernetes-ingress.git
cd kubernetes-ingress/
git checkout v1.5.0
cd ./deployments

kubectl apply -f common/ns-and-sa.yaml
kubectl apply -f common/default-server-secret.yaml
kubectl apply -f common/nginx-config.yaml
kubectl apply -f rbac/rbac.yaml
kubectl apply -f deployment/nginx-ingress.yaml

# With MetalLB, IP will be allocated automatically
kubectl patch -n ingress-nginx svc ingress-nginx --patch '{"spec": {"type": "LoadBalancer"}}'

# autocompletion
yum install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc

# disbled master node protection
# kubectl taint nodes --all node-role.Skubernetes.io/master-
