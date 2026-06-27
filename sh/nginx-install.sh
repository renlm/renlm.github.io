#!/bin/sh
set -e
set -o noglob
########################################################################
# https://nginx.org/en/docs/http/ngx_http_acme_module.html
# https://letsencrypt.org/docs/profiles
# https://letsencrypt.org/docs/acme-protocol-updates
### 一键安装
# $ curl -sfL https://renlm.github.io/sh/nginx-install.sh | REGISTRY_DOMAIN=registry.renlm.cn sh
########################################################################
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
NGINX_HOME=${DOCKER_ROOT}/deploy/nginx
NGINX_VERSION=${NGINX_VERSION:-"1.31.2-alpine"}
HTTP_PORT=${HTTP_PORT:-"80"}
HTTPS_PORT=${HTTPS_PORT:-"443"}
REGISTRY_CONF=conf.d/registry.conf
REGISTRY_PORT=${REGISTRY_PORT:-"5000"}
REGISTRY_DOMAIN=${REGISTRY_DOMAIN:-"registry.renlm.cn"}
ACME_ISSUER_CONTACT=${ACME_ISSUER_CONTACT:-"renlm@21cn.com"}
if [ -f ${NGINX_HOME}/docker-compose.yml ]; then
  echo "服务已存在：${NGINX_HOME}/docker-compose.yml"
else
  mkdir -p ${NGINX_HOME}/conf.d
  LOCAL_IP=$(hostname -I | cut -d ' ' -f1)
  LOCAL_NAMESERVERS=$(awk 'BEGIN{ORS=" "} $1=="nameserver" {if ($2 ~ ":") {print "["$2"]"} else {print $2}}' /etc/resolv.conf)
  cat <<EOF | tee ${DEPLOY_HOME}/init.sh >/dev/null
#!/bin/sh
set -e
set -o noglob

# 加载 ACME 模块
NGX_HTTP_ACME_MODULE_SO_WCL=\$(cat /etc/nginx/nginx.conf | grep "^load_module modules/ngx_http_acme_module.so;" | wc -l)
if [ \$NGX_HTTP_ACME_MODULE_SO_WCL -eq 0 ]; then
  echo "sed -i \"/^worker_processes/a\load_module modules/ngx_http_acme_module.so;\" /etc/nginx/nginx.conf"
  sed -i "/^worker_processes/a\load_module modules/ngx_http_acme_module.so;" /etc/nginx/nginx.conf
fi

EOF
  cat <<EOF | tee ${NGINX_HOME}/${REGISTRY_CONF} >/dev/null
resolver ${LOCAL_NAMESERVERS% } ipv6=off;
acme_shared_zone zone=ngx_acme_shared:1M;
acme_issuer acme-letsencrypt {
    uri         https://acme-v02.api.letsencrypt.org/directory;
    profile     shortlived;
    contact     ${ACME_ISSUER_CONTACT};
    state_path  /var/cache/nginx/acme-letsencrypt;
    accept_terms_of_service;
}

server {
    listen       443 ssl;
    server_name  ${REGISTRY_DOMAIN};
    
    acme_certificate      acme-letsencrypt;
    ssl_certificate       \$acme_certificate;
    ssl_certificate_key   \$acme_certificate_key;
    ssl_certificate_cache max=2;
    
    location / {
        proxy_pass http://${LOCAL_IP}:${REGISTRY_PORT};
    }
}

EOF
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
    - ${DEPLOY_HOME}/init.sh:/docker-entrypoint.d/init.sh
    - ${NGINX_HOME}/${REGISTRY_CONF}:/etc/nginx/${REGISTRY_CONF}
    - ${NGINX_HOME}/acme-letsencrypt:/var/cache/nginx/acme-letsencrypt
    
EOF
{
  chmod +x ${DEPLOY_HOME}/init.sh
  docker-compose -f ${NGINX_HOME}/docker-compose.yml up -d
}
fi
