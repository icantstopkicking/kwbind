.RECIPEPREFIX := >

PROGRAM := kwbind
SOURCE  := kwbind.lua

LUAJIT := $(shell command -v luajit 2>/dev/null)
GLUE   := $(shell command -v glue 2>/dev/null)
SRLUA  := $(shell command -v srluajit 2>/dev/null)

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean

all: build

check:
>test -n "$(LUAJIT)" || { echo "error: luajit not found in PATH"; exit 1; }
>test -n "$(GLUE)" || { echo "error: glue not found in PATH"; exit 1; }
>test -n "$(SRLUA)" || { echo "error: srluajit not found in PATH"; exit 1; }
>$(LUAJIT) -e 'assert(loadfile("$(SOURCE)"))'

build: check
>$(GLUE) "$(SRLUA)" "$(SOURCE)" "$(PROGRAM)"
>chmod +x "$(PROGRAM)"

install: build
>install -Dm755 "$(PROGRAM)" "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

uninstall:
>rm -f "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

clean:
>rm -f "$(PROGRAM)"
