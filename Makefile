SHELL = /bin/bash
.SHELLFLAGS := -o pipefail -c
.ONESHELL:

test/go:
	export PATH=$PATH:/usr/local/go/bin:/usr/local/bin:/usr/local/bin/terraform
	cd tests && go test
