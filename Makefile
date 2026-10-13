PACKAGE = pve-virtio-mem
ENV_HELPER := bash tools/pve-virtio-mem-env.sh --exec
.PHONY: all build test test-profile deb clean
all: test
build:
	@echo "Perl adapter; no compiled components"
test:
	$(ENV_HELPER) tests bash tests/virtio-mem/run.sh
test-profile:
	$(ENV_HELPER) tests bash scripts/test-profile.sh
deb:
	$(ENV_HELPER) deb bash scripts/build-deb.sh
clean:
	@test "$(CONFIRM_IDLE)" = yes
	$(ENV_HELPER) cleanup bash -c 'rm -rf "$$PROJECT_TMP_ROOT/cache" "$$PROJECT_TMP_ROOT/build" "$$PROJECT_TMP_ROOT/tests" "$$PROJECT_TMP_ROOT/logs" "$$PROJECT_TMP_ROOT/runs"'
