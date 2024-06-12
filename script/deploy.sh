#!/bin/bash

# Usage:
# ./deploy.sh <broadcast=false> <verify=false> <resume=false>
# 
# Environment variables:
# CHAIN:              Chain name to deploy to.
# ETHERSCAN_API_KEY:  API key for Etherscan verification. Should be specified in .env.
# RPC_URL:            URL for the RPC node. Should be specified in .env.
# VERIFIER_URL:       URL for the Etherscan API verifier. Should be specified when used on an unsupported chain.
# DEPLOYER_ACCOUNT:   Name of the stored account to use. Should be specified in .env. Private key should be in the foundry keystore.
# DEPLOYER_ACCOUNT_PASSWORD: Password for the stored account. Should be specified in .env.

# Load environment variables, but respect overrides
curenv=$(declare -p -x)
source .env
eval "$curenv"

# Get command-line arguments
BROADCAST=${1:-false}
VERIFY=${2:-false}
RESUME=${3:-false}

# Specify either of these variables to override the defaults
DEPLOY_SCRIPT=${DEPLOY_SCRIPT:-"./script/Deploy.s.sol"}
DEPLOY_CONTRACT=${DEPLOY_CONTRACT:-"Deploy"}

echo "Using deploy script and contract: $DEPLOY_SCRIPT:$DEPLOY_CONTRACT"
echo "Using RPC at URL: $RPC_URL"
echo "Using chain: $CHAIN"
if [ -n "$VERIFIER_URL" ]; then
  echo "Using verifier at URL: $VERIFIER_URL"
fi
echo "Deployer: $DEPLOYER_ADDRESS"
echo ""

# Set BROADCAST_FLAG based on BROADCAST
BROADCAST_FLAG=""
if [ "$BROADCAST" = "true" ] || [ "$BROADCAST" = "TRUE" ]; then
  BROADCAST_FLAG="--broadcast"
  echo "Broadcasting is enabled"
else
  echo "Broadcasting is disabled"
fi

# Set VERIFY_FLAG based on VERIFY
VERIFY_FLAG=""
if [ "$VERIFY" = "true" ] || [ "$VERIFY" = "TRUE" ]; then

  if [ -z "$VERIFIER" ] || [ "$VERIFIER" = "etherscan" ]; then
    # Check if ETHERSCAN_API_KEY is set
    if [ -z "$ETHERSCAN_API_KEY" ]; then
      echo "No Etherscan API key found. Provide the key in .env or disable verification."
      exit 1
    fi

    if [ -n "$VERIFIER_URL" ]; then
      VERIFY_FLAG="--verify --verifier-url $VERIFIER_URL --etherscan-api-key $ETHERSCAN_API_KEY"
    else
      VERIFY_FLAG="--verify --etherscan-api-key $ETHERSCAN_API_KEY"
    fi
  else
    if [ -n "$VERIFIER_URL" ]; then
      VERIFY_FLAG="--verify --verifier $VERIFIER --verifier-url $VERIFIER_URL"
    else
      VERIFY_FLAG="--verify --verifier $VERIFIER"
    fi
  fi
  echo "Verification is enabled"
else
  echo "Verification is disabled"
fi

# Set RESUME_FLAG based on RESUME
RESUME_FLAG=""
if [ "$RESUME" = "true" ] || [ "$RESUME" = "TRUE" ]; then
  RESUME_FLAG="--resume"
  echo "Resuming is enabled"
else
  echo "Resuming is disabled"
fi

# Deploy using script
forge script $DEPLOY_SCRIPT:$DEPLOY_CONTRACT --sig "deploy()()" \
--rpc-url $RPC_URL --account $DEPLOYER_ACCOUNT --password $DEPLOYER_ACCOUNT_PASSWORD --slow -vvv \
$BROADCAST_FLAG \
$VERIFY_FLAG \
$RESUME_FLAG