PACKAGE = pve-virtio-mem
ENV_HELPER := bash tools/pve-virtio-mem-env.sh --exec
.PHONY: all build test test-profile deb clean transparent-build transparent-test
all: test
build:
	@echo "Perl adapter; no compiled components"
test:
	$(ENV_HELPER) tests bash tests/virtio-mem/run.sh
test-profile:
	$(ENV_HELPER) tests bash scripts/test-profile.sh
deb:
	$(ENV_HELPER) deb bash scripts/build-deb.sh
transparent-build:
	$(ENV_HELPER) transparent bash experimental/transparent/build.sh
transparent-test:
	@test -n "$(TRANSPARENT_BUILD_DIR)" || { echo 'Set TRANSPARENT_BUILD_DIR to the experimental build directory'; exit 1; }
	$(ENV_HELPER) transparent python3 experimental/transparent/accept.py "$(TRANSPARENT_BUILD_DIR)"
clean:
	@test "$(CONFIRM_IDLE)" = yes
	$(ENV_HELPER) cleanup bash -c 'rm -rf "$$PROJECT_TMP_ROOT/cache" "$$PROJECT_TMP_ROOT/build" "$$PROJECT_TMP_ROOT/tests" "$$PROJECT_TMP_ROOT/logs" "$$PROJECT_TMP_ROOT/runs"'
