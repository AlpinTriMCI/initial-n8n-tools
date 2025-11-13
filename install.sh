#!/bin/bash

HOSTNAME=$(hostname)
DOMAIN="${HOSTNAME}.sandboxwork.my.id" # Set domain here
WEBHOOK_URL="https://api.devstech.web.id/webhooks"

# Helper send progress
send_progress() {
  local step="$1"
  local status="$2"
  local message="${3:-}"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # send json webhook
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"hostname\":\"$HOSTNAME\",\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" >/dev/null 2>&1
}

trap 'send_progress "setup" "failed" "Error occurred at line $LINENO: $(sed -n ${LINENO}p $0 | sed "s/\"/\\\"/g")"' ERR

set -e

send_progress "setup" "running"

send_progress "install_docker" "running"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install docker packages
sudo apt-get install -y docker-ce=5:28.5.2-1~ubuntu.22.04~jammy docker-ce-cli=5:28.5.2-1~ubuntu.22.04~jammy containerd.io docker-buildx-plugin docker-compose-plugin
# Mark Docker packages as hold to keep version 28.x — newer versions (>=29) are not yet fully supported by Traefik
sudo apt-mark hold docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start docker
sudo systemctl enable docker
sudo systemctl start docker

send_progress "install_docker" "success"

# Setup compose
COMPOSE_DIR="/opt/setup"
mkdir -p "$COMPOSE_DIR"

# Clone compose if repo doesn't exist
if [ -d "$COMPOSE_DIR/.git" ]; then
  cd "$COMPOSE_DIR"
  git pull
else
  git clone https://github.com/AlpinTriMCI/initial-n8n-tools.git "$COMPOSE_DIR" # Set git url
fi

# Create .env file for docker compose
cat <<EOF > .env
# DOMAIN_NAME and SUBDOMAIN together determine where n8n will be reachable from
# The top level domain to serve from
DOMAIN_NAME=${DOMAIN}

# The subdomain to serve from
SUBDOMAIN=n8n

# The above example serve n8n at: https://n8n.example.com

# Optional timezone to set which gets used by Cron and other scheduling nodes
# New York is the default value if not set
# GENERIC_TIMEZONE=Europe/Berlin

# The email address to use for the TLS/SSL certificate creation
SSL_EMAIL=user@${DOMAIN}
EOF

# Run docker compose
send_progress "build_compose" "running"

cd "$COMPOSE_DIR"
sudo docker compose up -d

send_progress "build_compose" "success"

send_progress "setup" "done" "Installation complete without errors"