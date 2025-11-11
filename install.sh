#!/bin/bash

set -e

echo "🚀 Start setup n8n environment"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
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
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start docker
sudo systemctl enable docker
sudo systemctl start docker

# Setup compose
COMPOSE_DIR="/opt/setup"
mkdir -p "$COMPOSE_DIR"

# Clone compose if repo doesn't exist
if [ ! -d "$COMPOSE_DIR/.git" ]; then
  echo "📦 Cloning compose repo..."
  git clone https://github.com/AlpinTriMCI/initial-n8n-tools.git "$COMPOSE_DIR"
fi

N8N_DOMAIN_NAME=$(hostname)
echo "🌐 Using domain: $N8N_DOMAIN_NAME"

# Create .env file for docker compose
echo "N8N_DOMAIN_NAME=${N8N_DOMAIN_NAME}" > "$COMPOSE_DIR/.env"

# Run docker compose
cd "$COMPOSE_DIR"
echo "🚢 Starting containers..."
docker compose up -d

# Running complete
echo "✅ Docker and Compose setup complete!"