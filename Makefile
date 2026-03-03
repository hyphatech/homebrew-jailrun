PROJECT_NAME := jrun-brew

BOLD := $(shell tput bold 2>/dev/null)
RESET := $(shell tput sgr0 2>/dev/null)

TAP_NS  ?= hyphatech/jailrun
FORMULA ?= jailrun
FULL    := $(TAP_NS)/$(FORMULA)

LOCAL_TAP_PATH ?= $(abspath .)
LOCAL_TAP_URL  := file://$(LOCAL_TAP_PATH)

TAP_DIR ?= /opt/homebrew/Library/Taps/hyphatech/homebrew-jailrun

.DEFAULT: help
.PHONY: help

help: ## show this help
	@echo ""
	@echo "$(BOLD)$(PROJECT_NAME)$(RESET)"
	@echo "========="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""

brew-clean: ## uninstall formula + remove cached downloads + cleanup (fast)
	@brew uninstall --force $(FULL) 2>/dev/null || true
	@rm -f "$$(brew --cache)/downloads/"*$(FORMULA)* 2>/dev/null || true
	@brew cleanup -s $(FORMULA) 2>/dev/null || true

brew-nuke: ## DEEP cleanup: uninstall + tmp/build dirs + untap + remove tap checkout + API/formula cache
	@echo "$(BOLD)==> uninstall + download cache$(RESET)"
	@brew uninstall --force $(FULL) 2>/dev/null || true
	@rm -f "$$(brew --cache)/downloads/"*$(FORMULA)* 2>/dev/null || true
	@brew cleanup -s $(FORMULA) 2>/dev/null || true

	@echo "$(BOLD)==> tmp/build artifacts$(RESET)"
	@rm -rf "$$(brew --cache)/$(FORMULA)" 2>/dev/null || true
	@rm -rf /private/tmp/$(FORMULA)--* 2>/dev/null || true
	@rm -rf /private/tmp/d$(FORMULA)--* 2>/dev/null || true
	@rm -rf "$$(brew --prefix)/Cellar/$(FORMULA)" 2>/dev/null || true

	@echo "$(BOLD)==> untap + remove tap checkout$(RESET)"
	@brew untap $(TAP_NS) 2>/dev/null || true
	@rm -rf $(TAP_DIR)

	@echo "$(BOLD)==> clear brew formula/api cache (forces re-read)$(RESET)"
	@rm -rf "$$(brew --cache)/Formula" 2>/dev/null || true
	@rm -rf "$$(brew --cache)/api" 2>/dev/null || true

brew-retap: ## tap from local repo (file://...), then show the formula header brew sees
	@echo "$(BOLD)==> ensuring local tap repo is committed$(RESET)"
	@git rev-parse --is-inside-work-tree >/dev/null 2>&1 || (echo "Not a git repo. Run: git init"; exit 1)
	@git rev-parse HEAD >/dev/null 2>&1 || (echo "No commits. Commit your Formula/ first."; exit 1)

	@echo "$(BOLD)==> tap from local$(RESET) $(LOCAL_TAP_URL)"
	@brew tap $(TAP_NS) $(LOCAL_TAP_URL)

	@echo "$(BOLD)==> brew formula path$(RESET)"
	@brew formula $(FULL)

	@echo "$(BOLD)==> brew sees (top of formula)$(RESET)"
	@brew cat $(FULL) | sed -n '1,40p'

brew-install: ## nuke everything, retap locally, install from source (verbose), then test
	@$(MAKE) brew-nuke
	@$(MAKE) brew-retap
	@echo "$(BOLD)==> install from source$(RESET)"
	@brew install --build-from-source -v $(FULL)
	@echo "$(BOLD)==> brew test$(RESET)"
	@brew test $(FULL) || true

brew-debug: ## print where brew loads formula from + deps + first lines
	@echo "$(BOLD)==> formula path$(RESET)"
	@brew formula $(FULL) || true
	@echo "$(BOLD)==> tap dir exists?$(RESET)"
	@test -d $(TAP_DIR) && echo "YES: $(TAP_DIR)" || echo "NO: $(TAP_DIR)"
