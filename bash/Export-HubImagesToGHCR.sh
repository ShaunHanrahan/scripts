#! /usr/bin/env bash

APP=winxuu

# Repository Name
repo="chkpwd/${APP}"

# Set tag(s)
curl -s 'https://hub.docker.com/v2/namespaces/chkpwd/repositories/winxuu/tags' | jq -r '.results[].name' | sort | while read tag; do
    # Pull the images from Docker Hub
    docker pull "${repo}:${tag}"

    # Tag the image
    docker tag "${repo}:${tag}" "ghcr.io/${repo}:${tag}"

    # Push the image to GHCR
    docker push "ghcr.io/${repo}:${tag}"
done
