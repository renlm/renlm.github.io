#!/bin/sh
set -e
set -o noglob
########################################################################
# https://nginx.org/en/docs/http/ngx_http_acme_module.html
# https://letsencrypt.org/docs/profiles
# https://letsencrypt.org/docs/acme-protocol-updates
### 一键安装
# [ {{LOCAL_IP}} ] 内置变量: 宿主机Ip
# $ curl -sfL https://renlm.github.io/sh/nginx-install.sh | \
#     sh -s - \
#     --acme registry.renlm.cn=http://{{LOCAL_IP}}:5000 \
#     --acme rancher.renlm.cn=http://{{LOCAL_IP}}:8080
########################################################################
DOCKER_ROOT=${DOCKER_ROOT:-"/data"}
NGINX_HOME=${DOCKER_ROOT}/deploy/nginx
NGINX_VERSION=${NGINX_VERSION:-"1.31.2-alpine"}
HTTP_PORT=${HTTP_PORT:-"80"}
HTTPS_PORT=${HTTPS_PORT:-"443"}
ACME_ISSUER_CONTACT=${ACME_ISSUER_CONTACT:-"renlm@21cn.com"}
ACME_CONFIG_ARR=""

# 颜色代码
_RED_='\033[0;31m'    # 红色
_GREEN_='\033[0;32m'  # 绿色
_YELLOW_='\033[0;33m' # 黄色
_NC_='\033[0m'        # 重置

# --- helper functions for logs ---
info()
{
  printf "[ ${_GREEN_}INFO${_NC_} ] $@\n"
}
warn()
{
  printf "[ ${_YELLOW_}WARN${_NC_} ] $@\n" >&2
}
fatal()
{
  printf "[ ${_RED_}ERROR${_NC_} ] $@\n" >&2
  exit 1
}

help=false
usage() {
  info "USAGE: $0 [--acme {域名}:{代理地址}]"
  info "  [-a|--acme {域名}:{代理地址}] 域名证书自动化配置."
  info "  [-h|--help] Usage message."
}

while [ $# -gt 0 ]; do
  key="$1"
  case $key in
    -a|--acme)
    ACME_CONFIG_ARR="$ACME_CONFIG_ARR $2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    help=true
    shift
    ;;
    *)
    usage
    exit 1
    ;;
  esac
done

if $help; then
  usage
  exit 0
fi

create_conf() {
  [ $# -eq 2 ] || fatal 'create_conf needs exactly 2 arguments'
  ACME_DOMAIN_NAME=$1
  ACME_PROXY_URL=$2
  ACME_PROXY_SCHEME=$(echo "$ACME_PROXY_URL" | cut -d ":" -f1)
  ACME_PROXY_SERVER=$(echo "$ACME_PROXY_URL" | cut -d "/" -f3)
  if [ ! -f ${NGINX_HOME}/conf.d/acme.conf ]; then
    mkdir -p ${NGINX_HOME}/conf.d
    info "Creating ${NGINX_HOME}/conf.d/acme.conf"
    cat <<EOF | tee ${NGINX_HOME}/conf.d/acme.conf >/dev/null
resolver \${LOCAL_RESOLVER} valid=30s ipv6=off;
acme_shared_zone zone=ngx_acme_shared:1M;
acme_issuer acme-letsencrypt {
    uri         https://acme-v02.api.letsencrypt.org/directory;
    profile     shortlived;
    contact     ${ACME_ISSUER_CONTACT};
    state_path  /var/cache/nginx/acme-letsencrypt;
    accept_terms_of_service;
}

map \$http_upgrade \$connection_upgrade {
    default Upgrade;
    ''      close;
}

EOF
fi
  if [ ! -f ${NGINX_HOME}/conf.d/${ACME_DOMAIN_NAME}.conf ]; then
    info "Creating ${NGINX_HOME}/conf.d/${ACME_DOMAIN_NAME}.conf"
    cat <<EOF | tee ${NGINX_HOME}/conf.d/${ACME_DOMAIN_NAME}.conf >/dev/null
upstream ${ACME_DOMAIN_NAME} {
    server ${ACME_PROXY_SERVER};
}

server {
    listen 80;
    server_name ${ACME_DOMAIN_NAME};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name ${ACME_DOMAIN_NAME};
    
    acme_certificate      acme-letsencrypt;
    ssl_certificate       \$acme_certificate;
    ssl_certificate_key   \$acme_certificate_key;
    ssl_certificate_cache max=2;
    
    client_max_body_size 1024m;
    
    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass ${ACME_PROXY_SCHEME}://${ACME_DOMAIN_NAME};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 900s;
        proxy_buffering off;
    }
    
    location = /robots.txt {
        default_type text/plain;
        return 200 "User-agent: *\nDisallow: /\n";
    }
}

EOF
fi
}

LOCAL_IP=$(hostname -I | cut -d ' ' -f1)
for acme_config in $ACME_CONFIG_ARR; do
  acme_domain_name=$(echo "${acme_config}" | cut -d "=" -f1)
  acme_proxy_url=$(echo "${acme_config}" | cut -d "=" -f2)
  acme_proxy_url=$(echo "${acme_proxy_url}" | sed "s/{{LOCAL_IP}}/${LOCAL_IP}/g")
  create_conf "$acme_domain_name" "$acme_proxy_url"
done

if [ -f ${NGINX_HOME}/docker-compose.yml ]; then
  info "docker exec -it nginx /docker-entrypoint.d/init.sh"
  docker exec -it nginx /docker-entrypoint.d/init.sh
  info "docker exec -it nginx nginx -s reload"
  docker exec -it nginx nginx -s reload
else
  mkdir -p ${NGINX_HOME}/conf.d
  info "Creating ${NGINX_HOME}/init.sh"
  cat <<EOF | tee ${NGINX_HOME}/init.sh >/dev/null
#!/bin/sh
set -e
set +o noglob

# 获取 Docker 内置 DNS 地址
for mnt_conf in "/mnt/conf.d"/*; do
  target_conf=/etc/nginx/conf.d/\${mnt_conf##*/}
  cp -f \${mnt_conf} \${target_conf}
  LOCAL_NAMESERVER=\$(awk 'BEGIN{ORS=" "} \$1=="nameserver" {if (\$2 ~ ":") {print "["\$2"]"} else {print \$2}}' /etc/resolv.conf)
  LOCAL_RESOLVER=\${LOCAL_NAMESERVER% }
  echo "sed -i \"s|\\\\\\\${LOCAL_RESOLVER}|\${LOCAL_RESOLVER}|g\" \${target_conf}"
  sed -i "s|\\\${LOCAL_RESOLVER}|\${LOCAL_RESOLVER}|g" \${target_conf}
done

# 加载 ACME 模块
NGX_HTTP_ACME_MODULE_SO_WCL=\$(cat /etc/nginx/nginx.conf | grep "^load_module modules/ngx_http_acme_module.so;" | wc -l)
if [ \$NGX_HTTP_ACME_MODULE_SO_WCL -eq 0 ]; then
  echo "sed -i \"/^worker_processes/a\load_module modules/ngx_http_acme_module.so;\" /etc/nginx/nginx.conf"
  sed -i "/^worker_processes/a\load_module modules/ngx_http_acme_module.so;" /etc/nginx/nginx.conf
fi

# 禁止所有爬虫抓取整个站点
if [ ! -f /usr/share/nginx/html/robots.txt ]; then
  echo "User-agent: *" > /usr/share/nginx/html/robots.txt
  echo "Disallow: /" >> /usr/share/nginx/html/robots.txt
fi

EOF
  echo "alias ll='ls -l'" > ${NGINX_HOME}/.ashrc
  info "Creating ${NGINX_HOME}/docker-compose.yml"
  cat <<EOF | tee ${NGINX_HOME}/docker-compose.yml >/dev/null
services:
  nginx:
    image: nginx:${NGINX_VERSION}
    working_dir: /etc/nginx
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
    environment:
      ENV: /etc/.ashrc
    volumes:
    - ${NGINX_HOME}/.ashrc:/etc/.ashrc
    - ${NGINX_HOME}/conf.d:/mnt/conf.d
    - ${NGINX_HOME}/init.sh:/docker-entrypoint.d/init.sh
    - ${NGINX_HOME}/acme-letsencrypt:/var/cache/nginx/acme-letsencrypt
    
EOF
{
  info "chmod +x ${NGINX_HOME}/init.sh"
  chmod +x ${NGINX_HOME}/init.sh
  info "docker-compose -f ${NGINX_HOME}/docker-compose.yml up -d"
  docker-compose -f ${NGINX_HOME}/docker-compose.yml up -d
}
fi
