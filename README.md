# Drone demo

## Demo to show drone 1.0.0-rc.9 breaks oauth flow

UPDATE: I finally found out the culprits that started this journey:

* oauth2 is case sensitive. OMFG, what days I spent debugging this. Haha. So my username (which I hardly use) is Morriz, and not morriz (which I always type).
* next up: I made the mistake to use `echo MYSECRET | base64` instead of `echo -n | ...` when manually creating the secret for drone (because the helm chart maker decided that was a smart thing to do). That is why I want everything as code....aaargh!

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
4. Run `helmfile --selector name=nginx-ingress --selector name=drone-08 apply` to start the stack
5. Run `sh bin/tunnel-to-ingress.sh` to connect the incoming traffic to the nginx-ingress node, and check if drone works at the given domain. If you followed the steps I bet you it does.
6. Go back to your oauth app in github and change the last part of the callback url, `authorize` to `login` and save.
7. `helmfile destroy` to kill the stack.
8.  Run `helmfile --selector name=nginx-ingress --selector name=drone-10 apply` and check again. I get a 401 "Bad Credentials".
    
### Debugging steps I performed:

#### 1. Client ID & secret check

Make sure the container is injected with the right client id and secret, which you can see in the drone container env:

    kubectl exec -ti $(kubectl get po -l app=drone --output=name | cut -c 5-) -- env | grep DRONE_SERVER_HOST

#### 2. X-Forwarded-For header check

After setting the debug level to 5 in the `nginx-ingress` chart I could see the exact headers being passed upstream.
For version 0.8 and 1.0 they both show the same, as the ingress-controller runs with the same config, and the ingress notations are the same for both services. Let's look how the response from github after requesting the auth session is passed upstream.

0.8 output:
```
GET /authorize?code=cb6d2a0e1c3de277ebf7&state=drone HTTP/1.1
Host: caa36249.eu.ngrok.io
X-Request-ID: f7fdc0f7f47cc2e0f1d8784fef0c8c5b
X-Real-IP: 172.17.0.1
X-Forwarded-For: 172.17.0.1
X-Forwarded-Host: caa36249.eu.ngrok.io
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Original-URI: /authorize?code=cb6d2a0e1c3de277ebf7&state=drone
X-Scheme: http
X-Original-Forwarded-For: 83.85.135.38
Pragma: no-cache
Cache-Control: no-cache
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Referer: http://caa36249.eu.ngrok.io/
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9,nl;q=0.8
```
1.0 output:
```
GET /login?code=3171b5455b29158b4466&state=78629a0f5f3f164f HTTP/1.1
Host: caa36249.eu.ngrok.io
X-Request-ID: 7c7081d0f04ed4849e7a0f3a7198e0ac
X-Real-IP: 172.17.0.1
X-Forwarded-For: 172.17.0.1
X-Forwarded-Host: caa36249.eu.ngrok.io
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Original-URI: /login?code=3171b5455b29158b4466&state=78629a0f5f3f164f
X-Scheme: http
X-Original-Forwarded-For: 83.85.135.38
Pragma: no-cache
Cache-Control: no-cache
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Referer: http://caa36249.eu.ngrok.io/
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9,nl;q=0.8
Cookie: _oauth_state_=4d65822107fcfd52
```
(Only difference: in the case of 1.0 the request is made to `/login` instead of `/authorize`.)

After reading the drone 1.0 configuration on `X-Forwarded-...` headers I though these values should be ok. I also tried another round with setting X-Forwarded-For to the real client ip (but got the same error redirect):
```
GET /login?code=6c56305dce5965ff2bee&state=4d65822107fcfd52 HTTP/1.1
Host: caa36249.eu.ngrok.io
X-Request-ID: 3dba9b55dc9f4f11ecc1415a89ca27b7
X-Real-IP: 83.85.135.38
X-Forwarded-For: 83.85.135.38
X-Forwarded-Host: caa36249.eu.ngrok.io
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Original-URI: /login?code=6c56305dce5965ff2bee&state=4d65822107fcfd52
X-Scheme: http
X-Original-Forwarded-For: 83.85.135.38
Pragma: no-cache
Cache-Control: no-cache
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Referer: http://caa36249.eu.ngrok.io/
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9,nl;q=0.8
Cookie: user_sess=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NTUyNDI3NTMsInRleHQiOiJNb3JyaXoiLCJ0eXBlIjoic2VzcyJ9.XEndtajwjcHzlH8dA2KApBnczGuVeqosGNJpuERj7IE; _oauth_state_=4d65822107fcfd52
```

#### 3. Next:

Next I would like to see detailed log output of a running drone server working throught the oauth flow.
I suspect a header naming change happened between 0.8.2 and 1.0.0.