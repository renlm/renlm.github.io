#!/bin/sh
set -e
set -o noglob
if [ -z "${HOST}" ] || [ -z "${ALIAS}" ] || [ -z "${FILE}" ]; then
	echo "tips: curl -sfL https://renlm.gitee.io/docs/sh/GitSSHCfg.sh | HOST={host} ALIAS={alias} FILE={file} sh"
elif [ ! -s ~/.ssh/${FILE} ]; then
	echo "tips: ssh-keygen -t ed25519 -C "\"${ALIAS}@${HOST}\"" -f ${FILE}"
else
tee -a ~/.ssh/config <<-EOF
Host ${ALIAS}
    HostName ${HOST}
    PreferredAuthentications publickey
    IdentityFile ${FILE}
EOF
fi