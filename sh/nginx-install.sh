#!/bin/sh
set -e
set -o noglob
########################################################################
# https://nginx.org/en/docs/http/ngx_http_acme_module.html
# https://letsencrypt.org/docs/profiles
# https://letsencrypt.org/docs/acme-protocol-updates
########################################################################
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
NGINX_HOME=${DOCKER_ROOT}/deploy/nginx
NGINX_VERSION=${NGINX_VERSION:-"1.31.2-alpine"}
if [ -f ${NGINX_HOME}/docker-compose.yml ]; then

fi
