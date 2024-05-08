#!/bin/sh
set -e
set -o noglob
if [ -z "${HOST}" ] || [ -z "${ALIAS}" ]; then
	echo "tips: curl -sfL https://renlm.github.io/script/sh/GitSSHCfg.sh | HOST={host} ALIAS={alias} sh"
elif [ ! -s ~/.ssh/id_${ALIAS} ]; then
	echo "tips: ssh-keygen -t ed25519 -C "\"${ALIAS}@${HOST}\"" -f ~/.ssh/id_${ALIAS}"
else
tee -a ~/.ssh/config <<-EOF
Host ${ALIAS}
    HostName ${HOST}
    PreferredAuthentications publickey
    IdentityFile ~/.ssh/id_${ALIAS}
EOF
fi