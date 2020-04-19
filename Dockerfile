#
# Builds a custom docker image for ShinobiCCTV Pro
#
FROM nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04
RUN apt update -y
RUN apt install wget -y
RUN wget https://deb.nodesource.com/setup_12.x
RUN chmod +x setup_12.x
RUN ./setup_12.x
RUN apt install nodejs -y

# Build arguments ...
# Shinobi's version information
ARG ARG_APP_VERSION

# The channel or branch triggering the build.
ARG ARG_APP_CHANNEL

# The commit sha triggering the build.
ARG ARG_APP_COMMIT

# Update Shinobi on every container start?
#   manual:     Update Shinobi manually. New Docker images will always retrieve the latest version.
#   auto:       Update Shinobi on every container start.
ARG ARG_APP_UPDATE=auto

# Build data
ARG ARG_BUILD_DATE

# Basic build-time metadata as defined at http://label-schema.org
LABEL org.label-schema.build-date=${ARG_BUILD_DATE} \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="GPLv3" \
    org.label-schema.name="MiGoller,moeiscool" \
    org.label-schema.vendor="Shinobi Systems" \
    org.label-schema.version="${ARG_APP_VERSION}-${ARG_APP_BRANCH}" \
    org.label-schema.description="Shinobi Pro - The Next Generation in Open-Source Video Management Software" \
    org.label-schema.url="https://gitlab.com/moeiscool/ShinobiDocker" \
    org.label-schema.vcs-ref=${ARG_APP_COMMIT} \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://gitlab.com/moeiscool/ShinobiDocker.git" \
    maintainer="MiGoller,moeiscool" \
    Author="MiGoller, mrproper, pschmitt & moeiscool"

# Persist app-related build arguments
ENV APP_VERSION=$ARG_APP_VERSION \
    APP_CHANNEL=$ARG_APP_CHANNEL \
    APP_COMMIT=$ARG_APP_COMMIT \
    APP_UPDATE=$ARG_APP_UPDATE \
    APP_BRANCH=${ARG_APP_BRANCH}

# Set environment variables to default values
# ADMIN_USER : the super user login name
# ADMIN_PASSWORD : the super user login password

ENV PLATERECOGNIZER_KEY=GETONLINE \
    PLATERECOGNIZER_ENDPOINT=https://api.platerecognizer.com/v1/plate-reader \
    ADMIN_USER=admin@shinobi.video \
    ADMIN_PASSWORD=admin \
    APP_PORT=8080 \
    CRON_KEY=fd6c7849-904d-47ea-922b-5143358ba0de \
    #leave these ENVs alone unless you know what you are doing
    MYSQL_USER=majesticflame \
    MYSQL_PASSWORD=password \
    MYSQL_HOST=localhost \
    MYSQL_DATABASE=ccio \
    MYSQL_ROOT_PASSWORD=blubsblawoot \
    MYSQL_ROOT_USER=root

# Create additional directories for: Custom configuration, working directory, database directory, scripts
RUN mkdir -p \
        /config \
        /opt/shinobi \
        /var/lib/mysql
RUN mkdir -p /customAutoLoad

# Assign working directory
WORKDIR /opt/shinobi

RUN export DEBIAN_FRONTEND="noninteractive"

# Install package dependencies
RUN apt update && apt install -y \
        libfreetype6-dev \
        libgnutls28-dev \
        libmp3lame-dev \
        libass-dev \
        libogg-dev \
        libtheora-dev \
        libvorbis-dev \
        libvpx-dev \
        libwebp-dev \
        libssh2-1-dev \
        libopus-dev \
        librtmp-dev \
        libx264-dev \
        libx265-dev \
        yasm && \
    apt-get install -y \
        build-essential \
        bzip2 \
        coreutils \
        gnutls-bin \
        nasm \
        tar \
        x264

# Install additional packages

RUN apt update && apt install -y \
        ffmpeg \
        git \
        make \
        mariadb-client \
        pkg-config \
        python \
        wget \
        tar \
        sudo \
        xz-utils \
        imagemagick


# Install MariaDB server... the debian way
RUN set -ex; \
	{ \
		echo "mariadb-server" mysql-server/root_password password '${MYSQL_ROOT_PASSWORD}'; \
		echo "mariadb-server" mysql-server/root_password_again password '${MYSQL_ROOT_PASSWORD}'; \
	} | debconf-set-selections; \
	apt-get update; \
	apt-get install -y \
		"mariadb-server" \
        socat \
	; \
    find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/'

RUN sed -ie "s/^bind-address\s*=\s*127\.0\.0\.1$/#bind-address = 0.0.0.0/" /etc/mysql/my.cnf

# Install Shinobi app including NodeJS dependencies
RUN git clone https://gitlab.com/Shinobi-Systems/Shinobi.git /opt/shinobi


RUN npm i npm@latest -g && \
    npm install pm2 -g && \
    npm install jsonfile && \
    npm install edit-json-file && \
    npm install ffbinaries && \
    npm install --unsafe-perm && \
    npm audit fix --force

#YOLO
WORKDIR /opt/shinobi/plugins/yolo

RUN cp conf.sample.json conf.json
# RUN sed -i -e 's/"port":8080/"port":8082/' conf.json

ENV weightNameExtension="-tiny" \
    GPU=1
RUN mkdir models
RUN wget -O models/yolov3.weights https://pjreddie.com/media/files/yolov3$weightNameExtension.weights
RUN mkdir models/cfg
RUN wget -O models/cfg/coco.data https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/coco.data
RUN wget -O models/cfg/yolov3.cfg https://raw.githubusercontent.com/pjreddie/darknet/master/cfg/yolov3$weightNameExtension.cfg
RUN mkdir models/data
RUN wget -O models/data/coco.names https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names

#ENV PATH="/usr/local/cuda/bin:${PATH}"
#ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
#ENV CPATH="/usr/local/cuda/targets/x86_64-linux/include:${CPATH}"

RUN npm install node-gyp -g --unsafe-perm
RUN npm install --unsafe-perm
RUN npm install node-yolo-shinobi --unsafe-perm
RUN echo "GPU $GPU"

# RUN pm2 start /opt/shinobi/plugins/yolo/shinobi-yolo.js

WORKDIR /opt/shinobi/

#END YOLO

# Copy code
COPY docker-entrypoint.sh ./docker-entrypoint.sh
COPY pm2Shinobi.yml ./
RUN chmod -f +x ./*.sh

# Copy default configuration files
COPY ./config/conf.sample.json ./config/super.sample.json /config/

VOLUME ["/opt/shinobi/videos"]
VOLUME ["/config"]
VOLUME ["/var/lib/mysql"]

EXPOSE 8080

ENTRYPOINT ["/opt/shinobi/docker-entrypoint.sh"]

CMD ["pm2-docker", "pm2Shinobi.yml"]