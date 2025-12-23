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
coverage-base :; forge coverage --fuzz-runs 50 --report lcov --no-match-coverage "(scripts|tests|deployments|mocks)"
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
	echidna tests/enigma-dark-invariants/protocol-suite/Tester.t.sol --contract Tester --config ./tests/enigma-dark-invariants/protocol-suite/_config/echidna_config.yaml
echidna-assert:
	echidna tests/enigma-dark-invariants/protocol-suite/Tester.t.sol --contract Tester --test-mode assertion --config ./tests/enigma-dark-invariants/protocol-suite/_config/echidna_config.yaml
echidna-explore:
	echidna tests/enigma-dark-invariants/protocol-suite/Tester.t.sol --contract Tester --test-mode exploration --config ./tests/enigma-dark-invariants/protocol-suite/_config/echidna_config.yaml

echidna-hub:
	echidna tests/enigma-dark-invariants/hub-suite/Tester.t.sol --contract Tester --config ./tests/enigma-dark-invariants/hub-suite/_config/echidna_config.yaml --server 3000
echidna-hub-assert:
	echidna tests/enigma-dark-invariants/hub-suite/Tester.t.sol --contract Tester --test-mode assertion --config ./tests/enigma-dark-invariants/hub-suite/_config/echidna_config.yaml --server 3000
echidna-hub-explore:
	echidna tests/enigma-dark-invariants/hub-suite/Tester.t.sol --contract Tester --test-mode exploration --config ./tests/enigma-dark-invariants/hub-suite/_config/echidna_config.yaml

# Medusa
medusa:
	medusa fuzz --config ./medusa.protocol.json
medusa-hub:
	medusa fuzz --config ./medusa.hub.json

foundry-invariants:
	forge test --mc TesterFoundry -vvv 

# Results
runes-echidna:
	runes convert ./tests/enigma-dark-invariants/protocol-suite/_corpus/echidna/default/_data/corpus/reproducers --output ./tests/enigma-dark-invariants/protocol-suite/replays
runes-medusa:
	runes convert ./tests/enigma-dark-invariants/protocol-suite/_corpus/medusa/ --output ./tests/enigma-dark-invariants/protocol-suite/replays

runes-echidna-hub:
	runes convert ./tests/enigma-dark-invariants/hub-suite/_corpus/echidna/default/_data/corpus/reproducers --output ./tests/enigma-dark-invariants/hub-suite/replays
runes-medusa-hub:
	runes convert ./tests/enigma-dark-invariants/hub-suite/_corpus/medusa/ --output ./tests/enigma-dark-invariants/hub-suite/replays