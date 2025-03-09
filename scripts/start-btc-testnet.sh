#!/usr/bin/env bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Bitcoin testnet container...${NC}"

# Define container name and image for consistency
CONTAINER_NAME="bitcoin-testnet"
BITCOIN_IMAGE="ruimarinho/bitcoin-core:latest"

# Define RPC credentials
RPC_USER="admin1"
RPC_PASS="123"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}Docker is not running or accessible${NC}"
  exit 1
fi

# Check if container is already running
if docker ps | grep -q $CONTAINER_NAME; then
  echo -e "${GREEN}Bitcoin testnet container is already running${NC}"
  
  # Set transaction fee settings even if already running
  echo "Updating transaction fee settings..."
  docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS settxfee 0.00001 || true
  echo -e "${GREEN}Transaction fee settings updated${NC}"
  
  exit 0
fi

# Check if container exists but is stopped
if docker ps -a | grep -q $CONTAINER_NAME; then
  echo "Removing existing stopped container..."
  docker rm $CONTAINER_NAME || true
fi

echo "Creating new Bitcoin testnet container..."
# Run the container with a specific name for easier reference
# This image has better ARM64 support
docker run -d --name $CONTAINER_NAME \
  -p 19001:18443 \
  -e BITCOIN_RPC_USER=$RPC_USER \
  -e BITCOIN_RPC_PASSWORD=$RPC_PASS \
  -e BITCOIN_RPC_ALLOW_IP=0.0.0.0/0 \
  $BITCOIN_IMAGE \
  -regtest=1 \
  -rpcbind=0.0.0.0 \
  -rpcallowip=0.0.0.0/0 \
  -rpcuser=$RPC_USER \
  -rpcpassword=$RPC_PASS \
  -fallbackfee=0.0001 \
  -maxtxfee=1.0 \
  -txconfirmtarget=1

# Wait for the container to start up
echo "Waiting for Bitcoin RPC service to start (this may take a few seconds)..."
sleep 10

# Verify container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
  echo -e "${RED}Container failed to start${NC}"
  
  # Show container logs
  echo "Container logs:"
  docker logs $CONTAINER_NAME 2>&1 || true
  
  # Remove the failed container
  docker rm $CONTAINER_NAME || true
  
  exit 1
fi

# Get container info
echo "Container info:"
docker ps | grep $CONTAINER_NAME

# Wait a bit more to ensure bitcoind is fully initialized
sleep 5

# Generate initial blocks for testing
echo "Creating wallet and generating initial blocks..."
docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS createwallet default 2>/dev/null || true
docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS loadwallet default 2>/dev/null || true

# Generate address and blocks
ADDRESS=$(docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS getnewaddress)
# Make sure address was returned
if [ -z "$ADDRESS" ]; then
  echo -e "${RED}Failed to generate address${NC}"
  docker logs $CONTAINER_NAME
  exit 1
fi

echo "Mining 101 blocks to make coins spendable"
docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS generatetoaddress 101 "$ADDRESS"

# Verify container is functioning correctly
echo "Verifying Bitcoin testnet setup..."
if docker exec $CONTAINER_NAME bitcoin-cli -regtest -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS getblockchaininfo; then
  echo -e "${GREEN}Bitcoin testnet ready for testing!${NC}"
  echo "RPC endpoint: http://localhost:19001"
  echo "Username: $RPC_USER"
  echo "Password: $RPC_PASS"
  exit 0
else
  echo -e "${RED}Failed to verify Bitcoin testnet setup${NC}"
  exit 1
fi