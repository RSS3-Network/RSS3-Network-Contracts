#!/usr/bin/env bash
#set -x

if [ ! -d "src" ]; then
	echo "error: script needs to be run from project root './tools/checkUpgradeable.sh'"
	exit 1
fi

# install slither
# on macos: brew install slither-analyzer
which slither-check-upgradeability
if [ $? -ne 0 ]; then
  git clone https://github.com/crytic/slither.git && cd slither || exit 1
  pip3 install .
  cd ..
fi

# create tmp files
file1=$(mktemp /tmp/contracts-slither-check.XXXXX) || exit 2
file2=$(mktemp /tmp/contracts-slither-check.XXXXX) || exit 2
file3=$(mktemp /tmp/contracts-slither-check.XXXXX) || exit 2

# slither-check
echo "Staking: " >"$file1"
slither-check-upgradeability . Staking \
--proxy-filename . \
--proxy-name TransparentUpgradeableProxy \
--compile-force-framework 'foundry' \
--exclude "initialize-target,missing-init-modifier" \
2>>"$file1" 1>&2


echo "Settlement: " >"$file2"
slither-check-upgradeability . Settlement \
--proxy-filename . \
--proxy-name TransparentUpgradeableProxy \
--compile-force-framework 'foundry' \
--exclude "initialize-target,missing-init-modifier,function-shadowing" \
2>>"$file2" 1>&2


echo "Chips: " >"$file3"
slither-check-upgradeability . Chips \
--proxy-filename . \
--proxy-name TransparentUpgradeableProxy \
--compile-force-framework 'foundry' \
--exclude "initialize-target,missing-init-modifier" \
2>>"$file3" 1>&2

# output43
lines1=$(sed -n '$=' "$file1")
lines2=$(sed -n '$=' "$file2")
lines3=$(sed -n '$=' "$file3")
# if the check fails, there will be 2+ lines in the files
if [ "$lines1" -gt 2 ] || [ "$lines2" -gt 2 ] || [ "$lines3" -gt 2 ]
then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "slither-check failed"
  cat "$file1"
  cat "$file2"
  cat "$file3"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 255
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "slither-check done"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
