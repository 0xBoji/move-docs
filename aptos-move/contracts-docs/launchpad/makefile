compile:
	@aptos move compile

create:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make create name=<profile_name>"; \
		exit 1; \
	fi
	aptos init --profile $(name) --network testnet

deploy:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make deploy name=<profile_name>"; \
		exit 1; \
	fi
	aptos move publish --profile $(name)

init:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make init name=<profile_name>"; \
		exit 1; \
	fi
	aptos move run --function-id main1::coinflip::create_vault --profile $(name)

callg:
	@if [ -z "$(name)" ] || [ -z "$(fun)" ] || [ -z "$(args)" ]; then \
		echo "Usage: make callg name=<profile_name> fun=<function_name> args='<arguments>'"; \
		exit 1; \
	fi
	aptos move run --function-id 0xd7805c990fe50efef595df50190f46adcf24a78345f3fa552908d0ba9c38f46c::coinflip::$(fun) --args $(args) --profile $(name)