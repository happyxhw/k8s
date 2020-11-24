# 快速搭建k8s开发环境

## 部署方式选择

对于开发环境，常见的快速部署 k8s 方式有：

> 1. kind
> 2. minikube
> 3. microk8s
> 4. rke(rancher)
> 5. ...

kind 简单使用过，特点是可以非常快的建立、销毁集群，单节点；

minikube 深度使用过，对于开发体验还不错，单节点；

microk8s 也使用过，体验也不错，ubuntu 出品的，针对快速开发和 loT，但是 snap 太恶心了，单机单节点，多机可以集群；

rke 是 rancher 出品的生产级 k8s 集群部署工具，部署过程非常顺利，可以部署多节点集群，这里我选取 rke 来部署一个单节点的 k8s 开发环境。

域名约定（/etc/hosts）（172.16.12.188 为虚拟机 ip）：

```
172.16.12.188 happyk8s.me     # dashboard   
172.16.12.188 grafana.me      # grafana
172.16.12.188 prometheus.me   # prometheus
172.16.12.188 kiali.me        # kiali
```



本文使用的所有文件都在：https://github.com/happyxhw/k8s



### 1、虚拟机准备

使用虚拟机的好处是：

1. 不破坏主机环境
2. 可以随时停止，停止后不占用主机资源
3. 重做方便，不担心出错

虚拟机配置：

> 虚拟机类型：kvm
>
> 系统：ubuntu-server 20.04 LTS
>
> CPU：4
>
> 内存：8G

archlinux/manjaro 安装 kvm 

```bash
sudo pacman -S libvirt qemu-headless ebtables virt-manager 
sudo systemctl start libvirt
sudo systemctl enable libvirt
systemctl status libvirt
```

ubuntu-server 20.04 安装 docker: https://docs.docker.com/engine/install/ubuntu/

```bash
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
```

安装相关工具：

```
# kubectl https://kubernetes.io/zh/docs/tasks/tools/install-kubectl/
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"

# helm v3 https://helm.sh/docs/intro/quickstart/
# https://github.com/helm/helm/releases

# rke 版本：v1.2.3
# https://rancher.com/docs/rke/latest/en/installation/

# istioctl 版本：v1.7.4
# https://istio.io/latest/docs/setup/getting-started/
# https://istio.io/latest/docs/setup/getting-started/#download
curl -L https://istio.io/downloadIstio | sh -
```

关闭 swap，防火墙（仅限开发环境）

```
sudo swapoff -a # 临时关闭
sudo vim /etc/fstab # 注释 swap 那一行，永久关闭 swap
sudo ufw disable
```

修改时间（如果集群请增加 ntp 时间同步）

```
sudo tzselect
sudo cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
```

修改 docker 镜像源，加快部署速度（我使用的是阿里云的镜像加速，大家可以自行设置）

```
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://m2ybj6zs.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

配置 localhost ssh key 登录

```shell
ssh-copy-id happyxhw@192.168.122.80
```



### ### rke 

请参考官方文档：https://rancher.com/docs/rke/latest/en/installation/

单机配置文件: rke/single-cluster.yml

```yml
nodes:
# 不能使用127.0.0.1，否则会有网络问题，一定要使用网卡的ip
  - internal_address: 192.168.122.80
    address: 192.168.122.80
    user: happyxhw
    role:
      - controlplane
      - etcd
      - worker
    ssh_key_path: /home/happyxhw/.ssh/id_rsa
    labels:
      app: ingress

# If set to true, RKE will not fail when unsupported Docker version
# are found
ignore_docker_version: true

# Cluster level SSH private key
# Used if no ssh information is set for the node

ssh_agent_auth: false

cluster_name: happyk8s

# kubernetes_version: v1.17.3-rancher1-1

authorization:
  mode: rbac

# Add-ons are deployed using kubernetes jobs. RKE will give
# up on trying to get the job status after this timeout in seconds..
addon_job_timeout: 30

# Specify network plugin-in (canal, calico, flannel, weave, or none)
network:
  plugin: canal

# Specify DNS provider (coredns or kube-dns)
dns:
  provider: coredns

# Currently only nginx ingress provider is supported.
# To disable ingress controller, set `provider: none`
# `node_selector` controls ingress placement and is optional
ingress:
  provider: nginx
  node_selector:
    app: ingress
```

三节点配置文件: rke/three-cluster.yml

```yml
nodes:
  - internal_address: 192.168.122.201
    address: 192.168.122.201
    user: k8s
    role:
      - controlplane
      - etcd
      - worker
    ssh_key_path: /home/k8s/.ssh/k8s_rsa

  - internal_address: 192.168.122.202
    address: 192.168.122.202
    user: k8s
    role:
      - worker
    ssh_key_path: /home/k8s/.ssh/k8s_rsa

  - internal_address: 192.168.122.203
    address: 192.168.122.203
    user: k8s
    role:
      - worker
    ssh_key_path: /home/k8s/.ssh/k8s_rsa
    labels:
      app: ingress

# If set to true, RKE will not fail when unsupported Docker version
# are found
ignore_docker_version: true

# Cluster level SSH private key
# Used if no ssh information is set for the node

ssh_agent_auth: false

cluster_name: happyk8s

# kubernetes_version: v1.17.3-rancher1-1

authorization:
  mode: rbac

# Add-ons are deployed using kubernetes jobs. RKE will give
# up on trying to get the job status after this timeout in seconds..
addon_job_timeout: 30

# Specify network plugin-in (canal, calico, flannel, weave, or none)
network:
  plugin: canal

# Specify DNS provider (coredns or kube-dns)
dns:
  provider: coredns

# Currently only nginx ingress provider is supported.
# To disable ingress controller, set `provider: none`
# `node_selector` controls ingress placement and is optional
ingress:
  provider: nginx
  node_selector:
    app: ingress
```

启动集群

```
rke up --config single_cluster.yml # 不指定配置文件，会读取当前目录下的 cluter.yml

# 如果出现 ssh 错误，检查ssh能否正常登录
# 如果出现 rke_netword_plugin 无法部署，检查主机ip是否正确（不能使用 127.0.0.1，localhost）
# 耐心的等待镜像拉取（墙，一生之敌），配置了阿里云的镜像代理后，理论所有镜像都能拉取下来
```

删除集群

```shell
rke remove --config single_cluster.yml
```

集群部署成功后，会在当前目录下生成 KUBECONFIG 文件，为了使用 kubectl，请设置环境变量

```shell
export KUBECONFIG="`pwd`/kube_config_cluster.yml"
# 也可以把文件复制到 ~/.kube/config，这样也可以不登录虚拟机使用kubectl
mkdir ~/.kube
touch ~/.kube/config
# 将 kube_config_cluster.yml 内容复制到任意机器的 ~/.kube/config
chmod 600 ~/.kube/config  # 不设置权限helm会警告
```



### ### 部署 dashboard

确定一个域名，加到主机的 /etc/hosts 里面：happyk8s.me

```
# /etc/hosts
192.168.122.80 happyk8s.me
```

```
# 一、生成 ssl secret
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout kube-dashboard.key -out kube-dashboard.crt -subj "/CN=happyk8s.me/O=happyk8s.me"
kubectl create secret tls kube-dasboard-ssl --key kube-dashboard.key --cert kube-dashboard.crt -n kubernetes-dashboard

# 二、deploy
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
# 如果下不下来，可以使用目录下的文件
kubectl apply -f recommend.yml

# 三、配置 rbac
kubectl apply -f admin-user.yml
kubectl apply -f admin-user-role.yml

# 四、获取登录用的token
kubectl -n kubernetes-dashboard describe secret admin-user-token | grep ^token
```

### 部署 kube-prometheus

```
git clone https://github.com/prometheus-operator/kube-prometheus
cd kube-prometheus
kubectl apply -f manifests/setup
kubectl apply -f manifests

# ingress
kubectl apply -f istio/grafana-ingress.yml      # 请根据需要调整域名
kubectl apply -f istio/prometheus-ingress.yml   # 请根据需要调整域名
```

等待部署完，浏览器打开 grafana.me 即可

### 部署 istio

```
istioctl install --set profile=default
# 等待完成
```

配置 promethues 对 istio-system 的权限

```
kubectl apply -f istio/prometheus/rbac.yml
```

配置 istio-system 的 service monitor

```
kubectl apply -f istio/monitor.yml
```

安装 kiali

```
helm install \
  --namespace istio-system \
  --set auth.strategy="anonymous" \
  --repo https://kiali.org/helm-charts \
  kiali-server \
  kiali-server
  
 # ingress
 kubectl apply -f istio/kiali-ingress.yml # kiali.me
```

修改 kiali 的configmap，主要是配置 promethues 的地址，默认的在 istio-system 分区，建议使用 dashboard 修改 istio-system 的 kiali configmap，这样比较方便

```yml
# 修改 external_services 为，grafana 同理
external_services:
  custom_dashboards:
    enabled: true
  prometheus:
    url: http://prometheus-k8s.monitoring.svc:9090
    
# 最好删掉原来的 kiali pod，这样就会使用新的 configmap
# 如果一切正常，kiali 大概率可以正常使用了（jaeger 除外）
```

**差不多就这么多了，其余大家自行探索**

