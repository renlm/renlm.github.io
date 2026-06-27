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
  cat <<EOF | tee ${NGINX_HOME}/init.sh >/dev/null
#!/bin/sh
set -e
set -o noglob

# 获取 Docker 内置 DNS 地址
cp -f /mnt/${REGISTRY_CONF} /etc/nginx/${REGISTRY_CONF}
LOCAL_NAMESERVER=\$(awk 'BEGIN{ORS=" "} \$1=="nameserver" {if (\$2 ~ ":") {print "["\$2"]"} else {print \$2}}' /etc/resolv.conf)
LOCAL_RESOLVER=\${LOCAL_NAMESERVER% }
echo "sed -i \"s|\\\\\\\${LOCAL_RESOLVER}|\${LOCAL_RESOLVER}|g\" /etc/nginx/${REGISTRY_CONF}"
sed -i "s|\\\${LOCAL_RESOLVER}|\${LOCAL_RESOLVER}|g" /etc/nginx/${REGISTRY_CONF}

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
  cat <<EOF | tee ${NGINX_HOME}/${REGISTRY_CONF} >/dev/null
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

server {
    listen 80;
    server_name ${REGISTRY_DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${REGISTRY_DOMAIN};
    
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
        proxy_pass http://${LOCAL_IP}:${REGISTRY_PORT};
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
  echo "alias ll='ls -l'" > ${NGINX_HOME}/.ashrc
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
    - ${NGINX_HOME}/init.sh:/docker-entrypoint.d/init.sh
    - ${NGINX_HOME}/${REGISTRY_CONF}:/mnt/${REGISTRY_CONF}
    - ${NGINX_HOME}/acme-letsencrypt:/var/cache/nginx/acme-letsencrypt
    
EOF
{
  chmod +x ${NGINX_HOME}/init.sh
  docker-compose -f ${NGINX_HOME}/docker-compose.yml up -d
}
fi
