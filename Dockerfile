FROM alpine:3.20 as build-env

WORKDIR /site

#build env
ENV HUGO_VERSION=0.128.2
ENV NOKOGIRI_VERSION=1.15.5
ENV HUGO_DOWNLOAD_URL=https://github.com/spf13/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz

RUN apk add --update --no-cache --virtual build-dependencies

# install some build prereqs
RUN apk add --update --no-cache \
		build-base \
		ca-certificates \
		curl \
		git \
        gcompat \
		tzdata \
		wget

RUN apk add dart-sass --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/

# download and install hugo
RUN wget "$HUGO_DOWNLOAD_URL" && \
	tar xzf hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz && \
	mv hugo /bin/hugo && \
	rm hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz LICENSE README.md || true

#copy the entire website folder into the build environment container
COPY . ./

#actually build the site
RUN hugo

# lets create the actual deployment image
FROM nginx:alpine

#copy over the site config for nginx
COPY ./.docker/default.conf /etc/nginx/conf.d/default.conf

#copy over the built website from the build environment docker
COPY --from=build-env /site/public /usr/share/nginx/html

# change permissions to allow running as arbitrary user
RUN chmod -R 777 /var/log/nginx /var/cache/nginx /var/run \
     && chgrp -R 0 /etc/nginx \
     && chmod -R g+rwX /etc/nginx

# use a different user as open shift wants non-root containers
# do it at the end here as it'll block our "root" commands to set the container up
USER 1000

#expose 8081 as we cant use port 80 on openshift (non-root restriction)
EXPOSE 8081