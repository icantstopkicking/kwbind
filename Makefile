.RECIPEPREFIX := >

PROGRAM := kwbind
SOURCE  := kwbind.lua

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean debug

all: build

check:
>@command -v luajit >/dev/null 2>&1 || { echo "error: luajit not found in PATH"; exit 1; }
>@luajit -e 'assert(loadfile("$(SOURCE)"))'

build: check
>@GLUE_PATH="$$(command -v glue)"; \
>SRLUA_PATH="$$(command -v srluajit)"; \
>if [ -z "$$GLUE_PATH" ]; then \
>    echo "error: glue not found in PATH"; \
>    exit 1; \
>fi; \
>if [ -z "$$SRLUA_PATH" ]; then \
>    echo "error: srluajit not found in PATH"; \
>    exit 1; \
>fi; \
>echo "glue:     $$GLUE_PATH"; \
>echo "srluajit: $$SRLUA_PATH"; \
>"$$GLUE_PATH" "$$SRLUA_PATH" "$(SOURCE)" "$(PROGRAM)"
>@chmod +x "$(PROGRAM)"

install: build
>install -Dm755 "$(PROGRAM)" "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

uninstall:
>rm -f "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

clean:
>rm -f "$(PROGRAM)"

debug:
>@echo "PATH=$$PATH"
>@echo "luajit=$$(command -v luajit || echo NOT_FOUND)"
>@echo "glue=$$(command -v glue || echo NOT_FOUND)"
>@echo "srluajit=$$(command -v srluajit || echo NOT_FOUND)"
