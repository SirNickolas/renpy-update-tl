.PHONY: all clean gtkdist build

DUB ?= dub
DUBFLAGS ?= -brelease-nobounds
7Z ?= 7z

ifeq ($(OS),Windows_NT)
    SUFFIX := .exe
    WINDEPS := gtkdist
else
    SUFFIX :=
    WINDEPS :=
endif

BUILD := build
NAME := renpy-update-tl
CLI := $(NAME)$(SUFFIX)
GUI := gui/$(NAME)-gui$(SUFFIX)
BIN := $(BUILD)/$(NAME)/bin
DLLS := $(BUILD)/dlls.txt
VERSION := $(shell cat views/version.txt)
ARCHIVE := $(BUILD)/$(NAME)-$(VERSION).7z

.PHONY: $(CLI) $(GUI)

all: $(ARCHIVE)

clean:
	$(RM) -r $(BUILD)

$(CLI):
	$(DUB) build $(DUBFLAGS)

$(GUI):
	cd $(@D) && $(DUB) build $(DUBFLAGS)

$(DLLS): $(GUI)
	@{ \
	set -eux; \
	mkdir -p $(@D); \
	cd $(^D); \
	./$(^F) & \
	pid=$$!; \
	cd - >/dev/null; \
	sleep 3; \
	scripts/listdlls.sh >$@; \
	kill -- "$$pid"; \
	}

gtkdist: $(DLLS)
	scripts/cpgtk.sh $(BUILD)/$(NAME)/ $^

build: $(CLI) $(GUI) $(WINDEPS)
	cp -r $(CLI) $(GUI) $(BIN)/

$(ARCHIVE): build
	cd $(@D) && $(7Z) a -uq0z1 $(@F) $(NAME)/ >/dev/null
