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
HTTP_PORT=${HTTP_PORT:-"80"}
HTTPS_PORT=${HTTPS_PORT:-"443"}
if [ -f ${NGINX_HOME}/docker-compose.yml ]; then
  LOCAL_IP=$(hostname -I | cut -d ' ' -f1)
  cat <<EOF | tee ${NGINX_HOME}/docker-compose.yml >/dev/null
services:
  nginx:
    image: nginx:${NGINX_VERSION}
    container_name: nginx
    hostname: nginx
    restart: always
    ports:
    - ${HTTP_PORT}:${HTTP_PORT}
    - ${HTTPS_PORT}:${HTTPS_PORT}
    healthcheck:
      test:
      - CMD
      - curl
      - -f
      - http://localhost:${HTTP_PORT}
      interval: 15s
      timeout: 3s
      retries: 4
    volumes:
    - ${NGINX_HOME}/acme-letsencrypt:/var/cache/nginx/acme-letsencrypt
    - ${NGINX_HOME}/conf.d/registry.conf:/etc/nginx/conf.d/registry.conf
    
EOF
{
  docker-compose -f ${NGINX_HOME}/docker-compose.yml up -d
}
fi
