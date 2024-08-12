#!/usr/bin/env bash
set -x

forge build --silent
jq '.abi' ./out/Events.sol/Events.json > deployments/abi/Events.abi
jq '.abi' ./out/Chips.sol/Chips.json > deployments/abi/Chips.abi
jq '.abi' ./out/Staking.sol/Staking.json > deployments/abi/Staking.abi
jq '.abi' ./out/Settlement.sol/Settlement.json > deployments/abi/Settlement.abi


