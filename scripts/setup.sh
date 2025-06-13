#!/bin/bash
set -e

# 1. Update and Upgrade System Packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install Docker if not already installed
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Installing docker.io..."
  sudo apt-get install docker.io -y
else
  echo "Docker is already installed."
fi

# 3. Add the current user to the docker group if not already present
if groups "$USER" | grep -q "\bdocker\b"; then
  echo "User '$USER' is already in the docker group."
else
  echo "Adding '$USER' to the docker group..."
  sudo usermod -aG docker "$USER"
  # Note: The group change may require a re-login; in an automation context this might be handled differently.
fi

# 4. Ensure the Docker service is running
if ! sudo systemctl is-active --quiet docker; then
  echo "Starting Docker service..."
  sudo systemctl start docker
else
  echo "Docker service is already running."
fi

# 5. Install Kind if not already installed
if ! command -v kind &> /dev/null; then
  echo "Kind not found. Installing Kind..."
  sudo curl -Lo /tmp/kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
  sudo chmod +x /tmp/kind
  sudo mv /tmp/kind /usr/local/bin/kind
else
  echo "Kind is already installed."
fi

# 6. Install kubectl if not already installed
if ! command -v kubectl &> /dev/null; then
  echo "kubectl not found. Installing kubectl..."
  # Download the latest stable kubectl
  sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
else
  echo "kubectl is already installed."
fi

# 7. Create the project directory and switch to it
PROJECT_DIR="/home/ubuntu/myproject"
echo "Ensuring project directory exists at: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 8. Set up the Kind configuration file only if it has changed
CONFIG_FILE="kind-config.yaml"
read -r -d '' EXPECTED_CONFIG <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4 
name: portfolio
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 30001
    hostPort: 30001
    protocol: TCP
EOF

if [ -f "$CONFIG_FILE" ]; then
  CURRENT_CONFIG=$(cat "$CONFIG_FILE")
else
  CURRENT_CONFIG=""
fi

if [ "$CURRENT_CONFIG" != "$EXPECTED_CONFIG" ]; then
  echo "Writing/updating the Kind configuration to $CONFIG_FILE..."
  echo "$EXPECTED_CONFIG" > "$CONFIG_FILE"
else
  echo "Kind configuration file is already up-to-date."
fi

# 9. Create the Kind cluster only if it doesn't already exist.
if kind get clusters | grep -Fxq "portfolio"; then
  echo "Kind cluster 'portfolio' already exists. Skipping creation."
else
  echo "Creating Kind cluster 'portfolio' using the provided configuration..."
  kind create cluster --config "$CONFIG_FILE" --name portfolio
fi

echo "Prerequisites and cluster setup are complete."
