# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes
test   :; forge test -vvv

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@npx prettier ${before} ${after} --write
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

gas-report :; forge test --mp 'tests/gas/**'

# Coverage
coverage-base :; FOUNDRY_PROFILE=coverage forge coverage --report lcov --no-match-coverage "(scripts|tests|deployments|mocks)"
coverage-clean :; lcov --rc derive_function_end_line=0 --remove ./lcov.info -o ./lcov.info.p --ignore-errors inconsistent 'src/dependencies/*'
coverage-report :; genhtml ./lcov.info.p -o report --branch-coverage --rc derive_function_end_line=0 
coverage-badge :; coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"
coverage :
	make coverage-base
	make coverage-clean
	make coverage-report
	make coverage-badge

# Echidna
echidna:
	echidna tests/invariants/protocol-suite/Tester.t.sol --contract Tester --config ./tests/invariants/protocol-suite/_config/echidna_config.yaml
echidna-assert:
	echidna tests/invariants/protocol-suite/Tester.t.sol --contract Tester --test-mode assertion --config ./tests/invariants/protocol-suite/_config/echidna_config.yaml
echidna-explore:
	echidna tests/invariants/protocol-suite/Tester.t.sol --contract Tester --test-mode exploration --config ./tests/invariants/protocol-suite/_config/echidna_config.yaml

echidna-hub:
	echidna tests/invariants/hub-suite/Tester.t.sol --contract Tester --config ./tests/invariants/hub-suite/_config/echidna_config.yaml
echidna-hub-assert:
	echidna tests/invariants/hub-suite/Tester.t.sol --contract Tester --test-mode assertion --config ./tests/invariants/hub-suite/_config/echidna_config.yaml
echidna-hub-explore:
	echidna tests/invariants/hub-suite/Tester.t.sol --contract Tester --test-mode exploration --config ./tests/invariants/hub-suite/_config/echidna_config.yaml

# Medusa
medusa:
	medusa fuzz --config ./medusa.protocol.json
medusa-hub:
	medusa fuzz --config ./medusa.hub.json

foundry-invariants:
	forge test --mc TesterFoundry -vvv 

# Results
runes-echidna:
	runes convert ./tests/invariants/protocol-suite/_corpus/echidna/default/_data/corpus/reproducers --output ./tests/invariants/protocol-suite/replays
runes-medusa:
	runes convert ./tests/invariants/protocol-suite/_corpus/medusa/ --output ./tests/invariants/protocol-suite/replays

runes-echidna-hub:
	runes convert ./tests/invariants/hub-suite/_corpus/echidna/default/_data/corpus/reproducers --output ./tests/invariants/hub-suite/replays
runes-medusa-hub:
	runes convert ./tests/invariants/hub-suite/_corpus/medusa/ --output ./tests/invariants/hub-suite/replays