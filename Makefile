.RECIPEPREFIX := >
.ONESHELL:

SHELL := /bin/sh
.SHELLFLAGS := -eu -c

PROGRAM := kwbind
SOURCE := kwbind.lua

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean paths

all: build

paths:
>printf 'PATH=%s\n' "$$PATH"
>for cmd in luajit glue srluajit; do
>    p="$$(command -v "$$cmd" 2>/dev/null || true)"
>    if [ -n "$$p" ]; then
>        p="$$(readlink -f "$$p")"
>    fi
>    printf '%-10s %s\n' "$$cmd" "$$p"
>done

check:
>LUAJIT="$$(command -v luajit 2>/dev/null || true)"
>[ -n "$$LUAJIT" ] || {
>    echo "error: luajit not found in PATH" >&2
>    exit 1
>}
>LUAJIT="$$(readlink -f "$$LUAJIT")"
>[ -x "$$LUAJIT" ] || {
>    echo "error: luajit is not executable: $$LUAJIT" >&2
>    exit 1
>}
>"$$LUAJIT" -e 'assert(loadfile("$(SOURCE)"))'

build: check
>GLUE="$$(command -v glue 2>/dev/null || true)"
>SRLUAJIT="$$(command -v srluajit 2>/dev/null || true)"
>
>[ -n "$$GLUE" ] || {
>    echo "error: glue not found in PATH" >&2
>    exit 1
>}
>
>[ -n "$$SRLUAJIT" ] || {
>    echo "error: srluajit not found in PATH" >&2
>    exit 1
>}
>
>GLUE="$$(readlink -f "$$GLUE")"
>SRLUAJIT="$$(readlink -f "$$SRLUAJIT")"
>
>[ -x "$$GLUE" ] || {
>    echo "error: glue is not executable: $$GLUE" >&2
>    exit 1
>}
>
>[ -r "$$SRLUAJIT" ] || {
>    echo "error: srluajit is not readable: $$SRLUAJIT" >&2
>    exit 1
>}
>
>[ -r "$(SOURCE)" ] || {
>    echo "error: source is not readable: $(SOURCE)" >&2
>    exit 1
>}
>
>printf 'Using glue: %s\n' "$$GLUE"
>printf 'Using srluajit: %s\n' "$$SRLUAJIT"
>
>"$$GLUE" "$$SRLUAJIT" "$(SOURCE)" "$(PROGRAM)"
>chmod +x "$(PROGRAM)"

install: build
>install -Dm755 "$(PROGRAM)" "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

uninstall:
>rm -f "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

clean:
>rm -f "$(PROGRAM)"
