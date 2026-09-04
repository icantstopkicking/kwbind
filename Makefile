.RECIPEPREFIX := >

PROGRAM := kwbind
SOURCE  := kwbind.lua

LUAJIT ?= luajit

GLUE  := /usr/local/bin/glue
SRLUA := /usr/local/bin/srluajit

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all check build install uninstall clean

all: build

check:
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
