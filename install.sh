#!/bin/bash

# ONLY FOR TEST
WEBHOOK_URL="https://api.devstech.web.id/webhooks"
HOSTNAME=$(hostname)
send_progress() {
  local step="$1"
  local status="$2"
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"hostname\":\"$HOSTNAME\",\"step\":\"$step\",\"status\":\"$status\"}" >/dev/null 2>&1
}

set -e

send_progress "setup" "running" # ONLY FOR TEST

echo "Start setup n8n environment"

send_progress "instal_docker" "running" # ONLY FOR TEST
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

send_progress "instal_docker" "success" # ONLY FOR TEST

# Create directory for traefik let's encrypt
sudo mkdir -p /etc/traefik/letsencrypt
sudo touch /etc/traefik/letsencrypt/acme.json
sudo chmod 600 /etc/traefik/letsencrypt/acme.json

# Setup compose
COMPOSE_DIR="/opt/setup"
mkdir -p "$COMPOSE_DIR"

# Clone compose if repo doesn't exist
if [ -d "$COMPOSE_DIR/.git" ]; then
  echo "Repo exists, pulling latest changes..."
  cd "$COMPOSE_DIR"
  git pull
else
  echo "Cloning compose repo..."
  git clone https://github.com/AlpinTriMCI/initial-n8n-tools.git "$COMPOSE_DIR" # Set git url
fi

HOSTNAME=$(hostname)
N8N_DOMAIN_NAME="${HOSTNAME}.sandboxwork.my.id" # Set subdomain here
echo "Using domain: $N8N_DOMAIN_NAME"

# Create .env file for docker compose
echo "N8N_DOMAIN_NAME=${N8N_DOMAIN_NAME}" | sudo tee "$COMPOSE_DIR/.env" > /dev/null

send_progress "build_compose" "running" # ONLY FOR TEST

# Run docker compose
cd "$COMPOSE_DIR"
echo "Starting containers..."
sudo docker compose up -d

send_progress "build_compose" "success" # ONLY FOR TEST

# Running complete
echo "Docker and Compose setup complete!"