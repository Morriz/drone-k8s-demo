#!/usr/bin/env bash

echo "Waiting for a node to talkubectl to"
until kubectl get nodes >/dev/null 2>&1; do
	sleep 1
	echo "."
done

echo "Setting up tiller"
kubectl apply -f tiller.yaml
helm init --upgrade --service-account tiller --history-max 0

echo "Waiting for Tiller to become available"
kubectl -n kube-system rollout status -w deploy/tiller-deploy

echo "[cluster] Installing secret for drone server"
kubectl apply -f drone-10-secret.yaml

echo "ALL DONE!\n"
