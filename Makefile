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

# Deployment
# Step 1:Pre-deploy LiquidationLogic library (required before deploying spokes)
# `make deploy-precompile chain=mainnet`
deploy-precompile :;
	forge script scripts/LibraryPreCompile.s.sol \
	--rpc-url ${chain} --account ${account} --ffi \
	$(if ${dry},, --broadcast) \

# Step 2: Deploy contracts + grant roles to deployer
# `make deploy-contracts chain=mainnet`
deploy-contracts :;
	forge script scripts/deploy/AaveV4Deploy.s.sol \
	--rpc-url ${chain} --account ${account} --slow \
	$(if ${dry},, --broadcast) \

config :;
	bun run scripts/config/generator/chaos/generate-config.ts

address-lib :;
	bun run scripts/payload/generator/generateContracts.ts ${chain}

payloads :;
	bun run scripts/payload/generator/generatePayload.ts

exec-payloads :;
	forge script scripts/Deploy.s.sol --rpc-url ${chain} --account ${account} --tc Deploy --sig "payload()" --slow \
	$(if ${dry},, --broadcast) \
	--priority-gas-price 1.5gwei --with-gas-price 2.5gwei \

tokenization :;
	bun run scripts/payload/generator/generateTokenizationSpoke.ts

exec-tokenization-1 :;
	forge script scripts/TokenizationSpokeDeploy.s.sol --rpc-url ${chain} --account ${account} --tc TokenizationSpokeDeploy --slow \
	$(if ${dry},, --broadcast) \
	--priority-gas-price 1.5gwei --with-gas-price 2.5gwei \

tokenization-payloads :;
	bun run scripts/payload/generator/generateTokenizationSpoke.ts --payload

exec-tokenization-2 :;
	forge script scripts/Deploy.s.sol --rpc-url ${chain} --account ${account} --tc Deploy --sig "tokenize()" --slow \
	$(if ${dry},, --broadcast) \
	--priority-gas-price 1.5gwei --with-gas-price 2.5gwei \

diff :;
	bun run scripts/payload/generator/generateDiffPayload.ts ${chain}
