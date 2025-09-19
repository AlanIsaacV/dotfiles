#!/bin/bash

set -ve
curl -LO https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz
tar -xf google-cloud-cli-darwin-arm.tar.gz -C ~/.gcloud

if type uv >/dev/null 2>&1; then
    CLOUDSDK_PYTHON=$(uv python find)
fi

~/.gcloud/google-cloud-sdk/install.sh
