#!/usr/bin/env bash

# Enable strict error handling
set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Timestamp function
timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Log function that adds timestamp
log() {
  echo -e "[$(timestamp)] $1"
}

# Header function for sections
header() {
  echo -e "\n${BOLD}${BLUE}========== $1 ==========${NC}\n"
}

# Start from a clean state - ensure any existing containers are stopped
cleanup_existing() {
  header "CLEANUP EXISTING CONTAINERS"
  log "${YELLOW}Checking for existing Bitcoin testnet containers...${NC}"
  
  if docker ps -a | grep -q "bitcoin-testnet"; then
    log "${YELLOW}Found existing containers. Cleaning up...${NC}"
    ./scripts/stop-btc-testnet.sh
    log "${GREEN}Cleanup completed successfully.${NC}"
  else
    log "${GREEN}No existing containers found. Starting fresh.${NC}"
  fi
}

# Start the Bitcoin testnet
start_testnet() {
  header "STARTING BITCOIN TESTNET"
  log "${YELLOW}Starting Bitcoin testnet container...${NC}"
  
  if ! ./scripts/start-btc-testnet.sh; then
    log "${RED}Failed to start Bitcoin testnet container. Exiting.${NC}"
    exit 1
  fi
  
  log "${GREEN}Bitcoin testnet started successfully.${NC}"
}

# Verify the network is working properly
verify_network() {
  header "VERIFYING NETWORK"
  log "${YELLOW}Verifying Bitcoin network is operational...${NC}"
  
  # Get blockchain info as a basic check
  BLOCKCHAIN_INFO=$(docker exec bitcoin-testnet bitcoin-cli -regtest -rpcuser=admin1 -rpcpassword=123 getblockchaininfo)
  BLOCKS=$(echo "$BLOCKCHAIN_INFO" | grep -o '"blocks": [0-9]*' | grep -o '[0-9]*')
  
  log "${GREEN}Network verification successful. Current block height: ${BLOCKS}${NC}"
  
  # Additional verification could be added here if needed
}

# Run the integration tests
run_tests() {
  header "RUNNING INTEGRATION TESTS"
  log "${YELLOW}Starting Bitcoin integration tests...${NC}"
  
  # Run the tests and capture the exit code
  pnpm hardhat test test/BTCTxBuilder.integration.test.ts
  TEST_RESULT=$?
  
  if [ $TEST_RESULT -eq 0 ]; then
    log "${GREEN}All tests passed successfully!${NC}"
  else
    log "${RED}Tests failed with exit code: $TEST_RESULT${NC}"
    TESTS_PASSED=false
  fi
  
  return $TEST_RESULT
}

# Final cleanup
cleanup() {
  header "CLEANING UP"
  log "${YELLOW}Stopping Bitcoin testnet and cleaning up...${NC}"
  
  if ! ./scripts/stop-btc-testnet.sh; then
    log "${RED}Warning: Cleanup may not have been complete.${NC}"
    log "${YELLOW}You may need to manually remove containers with:${NC}"
    log "docker ps | grep bitcoin | awk '{print \$1}' | xargs -r docker stop"
    log "docker ps -a | grep bitcoin | awk '{print \$1}' | xargs -r docker rm"
  else
    log "${GREEN}Cleanup completed successfully.${NC}"
  fi
}

# Main function
main() {
  header "BITCOIN E2E TEST WORKFLOW"
  log "${BOLD}Starting complete end-to-end test workflow${NC}"
  
  # Track if tests passed
  TESTS_PASSED=true
  
  # Set up trap to ensure cleanup on exit
  trap cleanup EXIT
  
  # Execute each step
  cleanup_existing
  start_testnet
  verify_network
  
  # Run tests
  if ! run_tests; then
    TESTS_PASSED=false
  fi
  
  # Final results
  header "TEST RESULTS"
  if [ "$TESTS_PASSED" = true ]; then
    log "${GREEN}${BOLD}E2E TEST WORKFLOW COMPLETED SUCCESSFULLY${NC}"
    exit 0
  else
    log "${RED}${BOLD}E2E TEST WORKFLOW FAILED${NC}"
    exit 1
  fi
}

# Execute main function
main 