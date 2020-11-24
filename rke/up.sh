ssh-keygen -f ~/.ssh/k8s_rsa
ssh-copy-id -i ~/.ssh/k8s_rsa k8s@192.168.122.101
rke up --config ./rancher-cluster.yml
rke remove --config ./rancher-cluster.yml

export KUBECONFIG=/home/happyxhw/docker-apps/microk8s/rancher/rke/kube_config_single-cluster.yml