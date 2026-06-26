#!/bin/sh
set -e
set -o noglob
########################################################################
### 加载离线镜像离线包
# $ tar -zxvf docker-registry.x86_64.tar.gz
# $ sh docker-registry/docker-load-images.sh
### 加载离线镜像包并推送到私有仓库
# $ tar -zxvf docker-registry.tar.gz
# $ TAG_ENABLE=true TAG_REGISTRY=registry.local:5000 sh docker-registry/docker-load-images.sh
########################################################################
SH_FILE=$0
SH_ROOT=${SH_FILE%/*}
IMAGES_TXT=${SH_ROOT}/${SH_ROOT}.txt
TAG_ENABLE=${TAG_ENABLE:-false}
TAG_REGISTRY=${TAG_REGISTRY:-"registry.local:5000"}
if [ -f $IMAGES_TXT ]; then
  # 导入镜像
  PLATFORM=$(head -n 1 $IMAGES_TXT)
  PLATFORM_NUM=$(( $(echo ${PLATFORM} | tr -cd ',' | wc -c) + 1 ))
  for i in $(seq 1 $PLATFORM_NUM); do
    PLATFORM_ITEM=$(echo "$PLATFORM" | cut -d ',' -f $i)
    TXT_LINE=0
    while IFS= read -r line; do
      TXT_LINE=$((TXT_LINE+1))
      if [ $TXT_LINE -gt 1 ]; then
        line_val=$(echo "$line" | cut -d "=" -f2)
        line_platform=$(echo "$line_val" | cut -d "@" -f1)
        line_tar=$(echo "$line_val" | cut -d "@" -f2)
        line_image=$(echo "$line_val" | cut -d "@" -f3)
        if [ $PLATFORM_ITEM = "$line_platform" ]; then
          docker load -i ${SH_ROOT}/$line_tar
          if [ "$TAG_ENABLE" = true ]; then
            docker tag $line_image ${TAG_REGISTRY}/$line_image
            docker push ${TAG_REGISTRY}/$line_image
            if [ $i -eq 2 ]; then
              PLATFORM1=$(echo "$PLATFORM" | cut -d ',' -f 1)
              PLATFORM2=$(echo "$PLATFORM" | cut -d ',' -f 2)
              docker buildx imagetools create \
                --tag ${TAG_REGISTRY}/${line_val} \
                ${TAG_REGISTRY}/${line_val}-${PLATFORM1##*/} \
                ${TAG_REGISTRY}/${line_val}-${PLATFORM2##*/}
            fi
          fi
        fi
      fi
    done < $IMAGES_TXT
  done
fi
