#!/bin/bash

host="${1}"
port="${2}"

[[ $host =~ ^gcp- ]] && host="${host#gcp-}"
[[ $host =~ ^gcp_trii- ]] && host="${host#gcp_trii-}"

[[ $host =~ ^gcp ]] && unset host
[[ $host =~ ^gcp_trii ]] && host="${host#gcp_trii-}"

get_ip () {
    local hostname="${1}"
    gcloud compute instances describe "${hostname}" \
        --format 'get(networkInterfaces.accessConfigs[0].natIP)'
}

if [[ -z $host ]]; then
    [[ -z $GCP_INSTANCE ]] && GCP_INSTANCE="${GCP_DEFAULT_INSTANCE}"

    if nc -z "${GCP_INSTANCE}" "${port}" &>/dev/null; then
        host=$GCP_INSTANCE
    else
        host=$(get_ip "${GCP_INSTANCE}")
    fi
else
    if ! nc -z "${host}" "${port}" &>/dev/null; then
        host=$(get_ip "${host}")
    fi
fi

[[ -z $host ]] && exit 1
nc "${host}" "${port}"

