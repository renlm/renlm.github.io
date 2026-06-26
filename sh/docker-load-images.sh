#!/bin/sh
set -e
set -o noglob

IMAGES_TXT=${IMAGES_TXT}
PLATFORM=$(head -n 1 $IMAGES_TXT)
PLATFORM_NUM=$(( $(echo ${PLATFORM} | tr -cd ',' | wc -c) + 1 ))
# 导入镜像
TXT_LINE=0
while IFS= read -r line; do
    TXT_LINE=$((TXT_LINE+1))
    if [ $TXT_LINE -gt 1 ]; then
      line_val=$(echo "$line" | cut -d "=" -f2)
      line_tar=$(echo "$line_val" | cut -d "@" -f2)
      docker load -i $line_tar
    fi
  done < ${IMAGES_TXT}
# 多架构
if [ $PLATFORM_NUM -gt 1 ]; then

fi
