#!/usr/bin/env bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define container name for consistency
CONTAINER_NAME="bitcoin-testnet"

# Define RPC credentials
RPC_USER="admin1"
RPC_PASS="123"

echo -e "${YELLOW}Stopping Bitcoin testnet container...${NC}"

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
  echo -e "${YELLOW}No Bitcoin testnet container is currently running${NC}"
  
  # Check if container exists but is stopped
  if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Removing stopped container..."
    docker rm $CONTAINER_NAME || true
    echo -e "${GREEN}Stopped container removed${NC}"
  else
    echo -e "${YELLOW}No Bitcoin testnet container found${NC}"
  fi
  
  # Kill any running bitcoin containers
  docker ps | grep bitcoin | awk '{print $1}' | xargs -r docker stop || true
  docker ps -a | grep bitcoin | awk '{print $1}' | xargs -r docker rm || true
  
  exit 0
fi

# Try to shut down the Bitcoin daemon gracefully first
echo "Attempting to stop Bitcoin daemon gracefully..."
docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS stop || true
sleep 5

# Stop the container
echo "Stopping container..."
docker stop $CONTAINER_NAME || true

# Remove the container
echo "Removing container..."
docker rm $CONTAINER_NAME || true

echo -e "${GREEN}Bitcoin testnet container stopped and removed${NC}"

# Optional: list running containers to verify
docker ps | grep bitcoin || echo "No Bitcoin containers running" 