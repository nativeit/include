#! /usr/env bash

###########################################################
# Staging
###########################################################

mkdir /tmp/nativeit
cp ${PWD}/scripts/lib/0-lib-bash-utils.sh /tmp/nativeit/lib-bash-utils.sh
cp ${PWD}/scripts/lib/0-lib-system-utils.sh /tmp/nativeit/lib-system-utils.sh
cp ${PWD}/scripts/lib/0-lib-system-debian.sh /tmp/nativeit/lib-system-debian.sh
cp ${PWD}/scripts/lib/0-setup-system.sh /tmp/nativeit/init.sh

chmod +x /tmp/nativeit/*.sh

echo "Type [ sh /tmp/init.sh ] into your prompt to start!"
