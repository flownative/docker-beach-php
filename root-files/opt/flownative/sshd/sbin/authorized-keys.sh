#!/bin/sh
# For example, beachPublicKeyServiceEndpoint=https://beach.flownative.com/api/v1
echo "\033[38;5;5m$(date "+%T.%2N ")\033[0m \033[38;5;2mINFO \033[0m  SSHD: Authorized Keys ${3}" >&2

beachPublicKeyServiceEndpoint=${3}
instanceIdentifier=$(hostname | grep -E -o '^(instance-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})' | cut -c 10-)
curl "${beachPublicKeyServiceEndpoint}"/ssh-keys?instance="${instanceIdentifier}"
