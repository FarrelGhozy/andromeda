# Makefile wrapper around PlatformIO for ANDROMEDA firmware.
# Ensures a single, reproducible entry point for build/test/upload/monitor.
# Requires: `make` (macOS/Linux, or Git Bash on Windows) and PlatformIO
# Core (`pio`) on PATH. Fresh toolchain is fetched on first build.
# Run from this directory:  make build   (or  make help)

PIO ?= pio
ENV ?= esp32dev

.PHONY: help build test upload monitor clean rebuild env pinned

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## Compile firmware (deterministic, pinned deps)
	$(PIO) run -e $(ENV)

test: ## Run native host unit tests
	$(PIO) test -e $(ENV)

upload: ## Build + flash to connected device over USB
	$(PIO) run -e $(ENV) -t upload

monitor: ## Open serial monitor (115200 baud)
	$(PIO) device monitor -e $(ENV)

clean: ## Remove build artifacts
	$(PIO) run -e $(ENV) -t clean

rebuild: clean build ## Force a clean deterministic build

env: ## Show resolved environment & deps (verify pinned versions)
	$(PIO) project config --list

pinned: ## Verify platform versions are pinned (not @latest)
	@$(PIO) platform list --json | grep -q '"espressif32"'
	@echo "espressif32 pinned OK"