# Docker Image for MongoDB 3.2.21 on RPi3

# This Dockerfile is inspired on the build instructions, by Koen Aerts:
# http://koenaerts.ca/compile-and-install-mongodb-on-raspberry-pi/

# When the docker host is a raspberry pi
# temporarily increase swap space on host with:
# sudo dd if=/dev/zero of=/mytempswapfile bs=1024 count=524288
# sudo chmod 0600 /mytempswapfile
# sudo mkswap /mytempswapfile
# sudo swapon /mytempswapfile
# Do not forget to delete the swap file after you reboot.

ARG mongod_version=3.2.21
ARG mongodb_archive_name="mongodb-src-r${mongod_version}"
ARG mongodb_archive="${mongodb_archive_name}.tar.gz"
ARG install_dir="/root/install/"
ARG src_dir=${install_dir}${mongodb_archive_name}
ARG target_dir="/root/target/"

# looks like there is a problem compiling against the newer libboost in stretch
# compilation fails under stretch, use a jessie image
FROM resin/rpi-raspbian:jessie as builder

ARG mongod_version
ARG mongodb_archive_name
ARG mongodb_archive
ARG install_dir
ARG src_dir
ARG target_dir

LABEL created_by=lowdefinition
LABEL mongod_version=${mongod_version}
LABEL inspired_on=http://koenaerts.ca/compile-and-install-mongodb-on-raspberry-pi/

# initialize the raspbian 
RUN apt update; \
    apt upgrade
    
# install dependencies
RUN apt install \
	scons \
	build-essential \
	libboost-filesystem-dev \
	libboost-program-options-dev \
	libboost-system-dev \ 
	libboost-thread-dev \ 
	python-pymongo \
	wget

# print out some version information for debugging purposes
#RUN cat docs/building.md; \
#    gcc --version; \
#    python --version; \
#    scons --version

# get mongodb sources
RUN mkdir ${install_dir}; \
    cd ${install_dir}; pwd; \
    curl -O https://fastdl.mongodb.org/src/${mongodb_archive}; \
    tar xvf ${mongodb_archive}

# generate additional sources
RUN cd ${src_dir}; pwd; \
    cd src/third_party/mozjs-38/ ; \
    ./get_sources.sh ; \
    export SHELL=/bin/sh; ./gen-config.sh arm linux

# compile, build and copy the executables
RUN cd ${src_dir}; pwd; \
    scons mongo mongod mongos --wiredtiger=off --mmapv1=on; \
    strip -s mongo*; \
    mkdir ${target_dir}; \
    cp mongo* ${target_dir}

# cleanup
RUN rm -rf ${install_dir}


FROM resin/rpi-raspbian:jessie

ARG mongod_version
ARG mongodb_archive_name
ARG mongodb_archive
ARG install_dir
ARG src_dir
ARG target_dir

LABEL created_by=lowdefinition
LABEL inspired_on=https://github.com/andresvidal/rpi3-mongodb3
LABEL mongod_version=${mongod_version}

# copy executables
WORKDIR /root
RUN echo ${target_dir}
COPY --from=builder ${target_dir} /usr/local/bin

# add configuration
RUN groupadd -r mongodb && useradd -r -g mongodb mongodb
RUN mkdir -p \
    /data/db \
    /data/configdb \
    /var/log/mongodb \
&& chown -R mongodb:mongodb \
    /usr/local/bin/mongo* \
    /data/db \
    /data/configdb \
    /var/log/mongodb

COPY ./docker-entrypoint.sh /
RUN ["chmod", "+x", "/docker-entrypoint.sh"]

# Define mountable directories
VOLUME /data/db /data/configdb

# Define working directory
WORKDIR /data

# Expose ports
# - 27017: process
# - 28017: http
EXPOSE 27017
EXPOSE 28017

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["mongod"]

# make sure that mongod performs a clean shutdown
# when container is stopped
STOPSIGNAL SIGINT
