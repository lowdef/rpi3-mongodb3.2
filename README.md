# MongoDB 3.2.21 for Raspberry Pi 3b+ (ARMv8) - Docker multi stage build Dockerfile

This multi stage  build Docker file builds the 32 bit ARM binaries for mongod, using the raspbian jessie image. This was done as the mongod did not compile under raspbian stretch. (Due to incompatibilities with newer version libboost libraries under stretch.)

*Where to find this:*

Github: https://github.com/lowdef/rpi3-mongodb3.2

Docker Hub: https://cloud.docker.com/repository/docker/lowdef/rpi3-mongodb3.2

# Information sources used and background information
First attempt to install mongodb I performed with the binary packages
compiled by Andy Felong:
https://andyfelong.com/2017/08/mongodb-3-0-14-for-raspbian-stretch/

This is however not the last version available. Unfortunately Andy
Felong did not publish his build setup.  The latest version at
the time of writing that should compile with 32 bit support is:
mongodb-src-r3.2.21.tar.gz

Tried to compile it using the build instructions, authored by Koen Aerts:
http://koenaerts.ca/compile-and-install-mongodb-on-raspberry-pi/

Unfortunately the compilation failed due to some libboost version
incompatibilities. The mongod source tree seems to rely on
libboost-1.56, stretch uses 1.62. Jessie uses 1.55 so I decided to
try to compile it within a raspbian:jessie docker container.

Using the compile instruction, adapt it to the latest available 3.2.21
sources from mongodb, and many attempts later I arrived at the multi
stage build Dockerfile as can be found in this repository.

The final container image that is constructed in the 2nd build phase
is inspired on Andres Vidals:
https://github.com/andresvidal/rpi3-mongodb3
It is basically a Dockerfile version of the installation instruction of
the binaries as provided by Andy Felong.

The last hurdle to take was that the mongod container did not provide
a clean shutdown when stopped, it left the database in an undefined
state prohibiting starting mongod again. This is caused due to docker
sending a SIGTERM signal to a container to stop it, but mongod only
performs a clean shutdown when it receives a SIGINT signal. This was
really annoying and for me made the solution not viable, all attempts
at having the entrypoint script trap the SIGTERM and convert it to a
SIGINT signal failed...

The following article saved my day:
https://hynek.me/articles/docker-signals/

The solution is simple, add a single line in your
Dockerfile:

```Dockerfile
STOPSIGNAL SIGINT
```

This will ensure that Docker stops the container with the SIGINT
signal, evoking the correct shutdown behaviour of mongod!  So now we
have a fully operational mongod running in a Docker raspbian:jessie
container on raspbian stretch. This will also ensure proper behaviour
of this container when the system is restarted, or docker is
restarted.

# Usage

**Prerequisites**

1. [Docker 17.11.0-ce+](https://www.google.com/search?q=installing+the+latest+docker+on+raspberry+pi+3)

## Build

This build takes a very long time.
The image is also uploaded on docker hub as "lowdef/rpi3-mongodb3.2".

## Build preparation
When the docker host is a raspberry pi temporarily increase swap space on host with:

```bash
sudo dd if=/dev/zero of=/mytempswapfile bs=1024 count=524288
sudo chmod 0600 /mytempswapfile
sudo mkswap /mytempswapfile
sudo swapon /mytempswapfile
```
## Now build the docker image

```bash
docker build -t rpi3-mongodb3.2 . | tee rpi3-mongodb3.2-build.log
```

Do not forget to delete the swap file after you reboot.

## Run

### Starting MongoDB 

```bash
$ docker run -d \
--name rpi3-mongodb3.2 \
--restart unless-stopped \
-v /data/db:/data/db \
-v /data/configdb:/data/configdb \
-p 27017:27017 \
-p 28017:28017 \
lowdef/rpi3-mongodb3.2 \
mongod --storageEngine mmapv1
```
Now mongodb can be used using your preferred client, be it PyMongo or mongo directly.

### Using it
Connect for example using PyMongo from the docker host:

```python
client = MongoClient('mongodb://localhost:27017')
```

Access the database with mongo directly:

```bash
docker exec -it mongodb3.2 mongo
```

Repairing the database when something has gone wrong, i.e. mongod does not start due to a previous unclean shutdown:
```bash
docker run -d --name mongodb3.2v2 -v /data/db:/data/db -v /data/configdb:/data/configdb -p 27017:27017 -p 28017:28017 rpi3-mongodb3.2:v2 mongod --repair
docker container prune
```







