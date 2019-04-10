# Drone demo

## Demo to show drone 1.0.0-rc.9 breaks oauth flow

I was running one of the first drone helm charts that ran with docker image `docker.io/drone/drone:0.8.2` and all was well. (It was actually version 0.1.0 and I had to put it in this repo under `charts/drone` because it's too old and hard to find.)

Then I decided to upgrade and went with the latest `stable/drone --version2.0.0-rc.9` helm chart running the latest docker image `docker.io/drone/drone:1.0.0-rc.5`.

Somehow that broke the oauth flow and led to a 401 'Bad Credentials' from Github, which usually means it does not recognize the client id or secret. Upon inspection I noticed that in both instances the client id was correct but I could not debug the hashed secret being sent. Nor was I able to get a detailed log output from drone what it was doing. I spent many hours to make sure I was not making a mistake with the configuration of the new drone version, and am now in need of help. 

So by publishing this I am hoping somebody will point out why this happens, or points me towards a solution that still allows me to run drone behind an ingress.

## Let me show you what I encountered

Before you start make sure you have:
- minikube installed
- helmfile installed: `brew install helmfile`
- an ngrok domain routing to your laptop. Just run `ngrok http 80` to start a temp domain. Don't forget to keep it running or you lose that tmp domain name!
- Create an [oauth app](https://github.com/settings/developers) (using the ngrok http url) and remember the client id and secret.

### Demo Steps:

1. start minikube and wait for k8s to come alive.

    minikube start

2. Copy `env.sample.sh` to `env.sh` and put all the values in `env.sh`, and source them `. ./env.sh`.
3. Run `sh bin/install-prerequisites.sh` to install tiller.
4. Run `helmfile --selector name=nginx-ingress apply` to start nginx-ingress.
5. Run `sh bin/tunnel-to-ingress.sh` to connect the incoming traffic to the nginx-ingress node.
6. Run `helmfile --selector name=drone-08 apply` and check if drone domain works at the given domain. I bet you it does.
7. Go back to your oauth app and change the last part of the callback url, `authorize` to `login` and save.
8. `helm delete drone-08 --purge` to kill the old drone.
9. Run `helmfile --selector name=drone-10 apply` and check again. I get a 401 "Bad Credentials".