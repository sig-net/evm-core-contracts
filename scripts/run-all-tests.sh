#!/usr/bin/env bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine if cleanup is requested
CLEANUP=0
AUTO_CLEANUP=0

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup)
      CLEANUP=1
      shift
      ;;
    --auto-cleanup)
      AUTO_CLEANUP=1
      shift
      ;;
    *)
      # Unknown option
      shift
      ;;
  esac
done

# Function to cleanup if requested or on error
cleanup() {
  if [[ $CLEANUP -eq 1 || $AUTO_CLEANUP -eq 1 ]]; then
    echo -e "${YELLOW}Cleaning up Bitcoin testnet container...${NC}"
    ./scripts/stop-btc-testnet.sh
  else
    echo -e "${YELLOW}Bitcoin testnet container left running.${NC}"
    echo "Run './scripts/stop-btc-testnet.sh' when you're done testing."
  fi
}

# Set trap for cleanup on script exit if auto-cleanup is enabled
if [[ $AUTO_CLEANUP -eq 1 ]]; then
  trap cleanup EXIT
fi

echo -e "${YELLOW}Running all tests - this will start the Bitcoin testnet container if needed${NC}"

# First ensure Bitcoin testnet is running
if ! ./scripts/start-btc-testnet.sh; then
  echo -e "${RED}Failed to start Bitcoin testnet container${NC}"
  exit 1
fi

# Run all tests
echo -e "${YELLOW}Running all tests...${NC}"

# Run EVM tests first (faster)
echo -e "${YELLOW}Running EVM transaction builder tests...${NC}"
pnpm hardhat test test/EVMTxBuilder.test.ts
EVM_TEST_RESULT=$?

if [[ $EVM_TEST_RESULT -eq 0 ]]; then
  echo -e "${GREEN}EVM tests completed successfully!${NC}"
else
  echo -e "${RED}EVM tests failed with exit code: $EVM_TEST_RESULT${NC}"
fi

# Run BTC tests (requires container)
echo -e "${YELLOW}Running BTC transaction builder tests...${NC}"
pnpm hardhat test test/BTCTxBuilder.integration.test.ts
BTC_TEST_RESULT=$?

if [[ $BTC_TEST_RESULT -eq 0 ]]; then
  echo -e "${GREEN}BTC tests completed successfully!${NC}"
else
  echo -e "${RED}BTC tests failed with exit code: $BTC_TEST_RESULT${NC}"
fi

# Cleanup if requested
if [[ $CLEANUP -eq 1 ]]; then
  cleanup
else
  echo "You can stop the Bitcoin testnet with: ./scripts/stop-btc-testnet.sh"
fi

# Return the combined result
if [[ $EVM_TEST_RESULT -eq 0 && $BTC_TEST_RESULT -eq 0 ]]; then
  echo -e "${GREEN}All tests completed successfully!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed. Please check the output above.${NC}"
  exit 1
fi 