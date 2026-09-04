.RECIPEPREFIX := >

PROGRAM := kwbind
SOURCE := kwbind.lua

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean paths

all: build

paths:
>@set -eu; \
>for cmd in luajit glue srluajit; do \
>	p="$$(command -v "$$cmd" 2>/dev/null || true)"; \
>	printf '%-10s %s\n' "$$cmd" "$$p"; \
>done

check:
>@set -eu; \
>LUAJIT="$$(command -v luajit 2>/dev/null || true)"; \
>if [ -z "$$LUAJIT" ]; then \
>	echo "error: luajit not found in PATH" >&2; \
>	exit 1; \
>fi; \
>"$$LUAJIT" -e 'assert(loadfile("$(SOURCE)"))'

build: check
>@set -eu; \
>GLUE="$$(command -v glue 2>/dev/null || true)"; \
>SRLUAJIT="$$(command -v srluajit 2>/dev/null || true)"; \
>if [ -z "$$GLUE" ]; then \
>	echo "error: glue not found in PATH" >&2; \
>	exit 1; \
>fi; \
>if [ -z "$$SRLUAJIT" ]; then \
>	echo "error: srluajit not found in PATH" >&2; \
>	exit 1; \
>fi; \
>echo "Using glue: $$GLUE"; \
>echo "Using srluajit: $$SRLUAJIT"; \
>"$$GLUE" "$$SRLUAJIT" "$(SOURCE)" "$(PROGRAM)"; \
>chmod +x "$(PROGRAM)"

install: build
>install -Dm755 "$(PROGRAM)" "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

uninstall:
>rm -f "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

clean:
>rm -f "$(PROGRAM)"
