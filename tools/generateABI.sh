#!/usr/bin/env bash
set -x

ABI_DIR=./deployments/abi/

forge build --silent

for contract in Staking Chips Settlement Events NetworkParams
do
  # extract abi and bin files
  forge inspect ${contract} abi > ${ABI_DIR}/${contract}.abi
done
