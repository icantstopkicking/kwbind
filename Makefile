.RECIPEPREFIX := >

PROGRAM := kwbind
SOURCE := kwbind.lua

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean paths

all: build

paths:
>@printf 'PATH       = %s\n' "$$PATH"
>@printf 'luajit     = %s\n' "$$(command -v luajit 2>/dev/null || true)"
>@printf 'glue       = %s\n' "$$(command -v glue 2>/dev/null || true)"
>@printf 'srluajit   = %s\n' "$$(command -v srluajit 2>/dev/null || true)"

check:
>@command -v luajit >/dev/null 2>&1 || { \
>	echo "error: luajit not found in PATH"; \
>	exit 1; \
>}
>@luajit -e 'assert(loadfile("$(SOURCE)"))'

build: check
>@set -e; \
>GLUE_PATH="$$(command -v glue 2>/dev/null)"; \
>SRLUA_PATH="$$(command -v srluajit 2>/dev/null)"; \
>if [ -z "$$GLUE_PATH" ]; then \
>	echo "error: glue not found in PATH"; \
>	exit 1; \
>fi; \
>if [ -z "$$SRLUA_PATH" ]; then \
>	echo "error: srluajit not found in PATH"; \
>	exit 1; \
>fi; \
>echo "Using glue:     $$GLUE_PATH"; \
>echo "Using srluajit: $$SRLUA_PATH"; \
>ls -l "$$GLUE_PATH" "$$SRLUA_PATH"; \
>"$$GLUE_PATH" "$$SRLUA_PATH" "$(SOURCE)" "$(PROGRAM)"
>@chmod +x "$(PROGRAM)"

install: build
>install -Dm755 "$(PROGRAM)" "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

uninstall:
>rm -f "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

clean:
>rm -f "$(PROGRAM)"
