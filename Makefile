.RECIPEPREFIX := >

PROGRAM := kwbind
SOURCE  := kwbind.lua

LUAJIT ?= luajit
GLUE   ?= glue
SRLUA  ?= $(shell command -v srluajit)

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean

all: build

check:
>test -n "$(SRLUA)" || (echo "srluajit not found in PATH"; exit 1)
>command -v $(GLUE) >/dev/null || (echo "glue not found in PATH"; exit 1)
>command -v $(LUAJIT) >/dev/null || (echo "luajit not found in PATH"; exit 1)
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
