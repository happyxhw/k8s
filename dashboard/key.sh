openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout kube-dashboard.key -out kube-dashboard.crt -subj "/CN=happyk8s.me/O=happyk8s.me"

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml

kubectl create secret tls kube-dasboard-ssl --key kube-dashboard.key --cert kube-dashboard.crt -n kubernetes-dashboard

