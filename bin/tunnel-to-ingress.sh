#!/usr/bin/env bash
local_ip=127.0.0.1

sudo killall ssh >/dev/null 2>&1

# minikube tunnel --cleanup &>/dev/null 2>&1

# loadbalancerIP=$(kubectl -n system get svc nginx-ingress-controller -o yaml | grep clusterIP |  cut -c 14-)
# loadbalancerIP=$(minikube ip)
loadbalancerIP=127.0.0.1

# port forward incoming 80,443 to nginx portforward that we created in dashboards.sh
sudo ssh -N -p 22 -g $USER@$local_ip -L $local_ip:443:$loadbalancerIP:32443 -L $local_ip:80:$loadbalancerIP:32080 &
