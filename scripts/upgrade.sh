#!/bin/bash
## Do not modify this file. You will lose the ability to autoupdate!

VERSION="15"
CDN="https://cdn.coollabs.io/coolify"
LATEST_IMAGE=${1:-latest}
LATEST_HELPER_VERSION=${2:-latest}
REGISTRY_URL=${3:-ghcr.io}

DATE=$(date +%Y-%m-%d-%H-%M-%S)
LOGFILE="/data/coolify/source/upgrade-${DATE}.log"

curl -fsSL $CDN/docker-compose.yml -o /data/coolify/source/docker-compose.yml
curl -fsSL $CDN/docker-compose.prod.yml -o /data/coolify/source/docker-compose.prod.yml
curl -fsSL $CDN/.env.production -o /data/coolify/source/.env.production

# Merge .env and .env.production. New values will be added to .env
awk -F '=' '!seen[$1]++' /data/coolify/source/.env /data/coolify/source/.env.production >/data/coolify/source/.env.tmp && mv /data/coolify/source/.env.tmp /data/coolify/source/.env
# Check if PUSHER_APP_ID or PUSHER_APP_KEY or PUSHER_APP_SECRET is empty in /data/coolify/source/.env
if grep -q "PUSHER_APP_ID=$" /data/coolify/source/.env; then
    sed -i "s|PUSHER_APP_ID=.*|PUSHER_APP_ID=$(openssl rand -hex 32)|g" /data/coolify/source/.env
fi

if grep -q "PUSHER_APP_KEY=$" /data/coolify/source/.env; then
    sed -i "s|PUSHER_APP_KEY=.*|PUSHER_APP_KEY=$(openssl rand -hex 32)|g" /data/coolify/source/.env
fi

if grep -q "PUSHER_APP_SECRET=$" /data/coolify/source/.env; then
    sed -i "s|PUSHER_APP_SECRET=.*|PUSHER_APP_SECRET=$(openssl rand -hex 32)|g" /data/coolify/source/.env
fi

# Make sure coolify network exists
# It is created when starting Coolify with docker compose
if ! docker network inspect coolify >/dev/null 2>&1; then
    if ! docker network create --attachable --ipv6 coolify 2>/dev/null; then
        echo "Failed to create coolify network with ipv6. Trying without ipv6..."
        docker network create --attachable coolify 2>/dev/null
    fi
fi
# docker network create --attachable --driver=overlay coolify-overlay 2>/dev/null

# Check if Docker config file exists
DOCKER_CONFIG_MOUNT=""
if [ -f /root/.docker/config.json ]; then
    DOCKER_CONFIG_MOUNT="-v /root/.docker/config.json:/root/.docker/config.json"
fi

if [ -f /data/coolify/source/docker-compose.custom.yml ]; then
    echo "docker-compose.custom.yml detected." >>$LOGFILE
    docker run -v /data/coolify/source:/data/coolify/source -v /var/run/docker.sock:/var/run/docker.sock ${DOCKER_CONFIG_MOUNT} --rm ${REGISTRY_URL:-ghcr.io}/coollabsio/coolify-helper:${LATEST_HELPER_VERSION} bash -c "LATEST_IMAGE=${LATEST_IMAGE} docker compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml -f /data/coolify/source/docker-compose.custom.yml up -d --remove-orphans --force-recreate --wait --wait-timeout 60" >>$LOGFILE 2>&1
else
    docker run -v /data/coolify/source:/data/coolify/source -v /var/run/docker.sock:/var/run/docker.sock ${DOCKER_CONFIG_MOUNT} --rm ${REGISTRY_URL:-ghcr.io}/coollabsio/coolify-helper:${LATEST_HELPER_VERSION} bash -c "LATEST_IMAGE=${LATEST_IMAGE} docker compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d --remove-orphans --force-recreate --wait --wait-timeout 60" >>$LOGFILE 2>&1
fi
