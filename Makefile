.PHONY: all clean

DUB ?= dub
DUBFLAGS ?= -brelease-nobounds

ifeq ($(OS),Windows_NT)
    SUFFIX := .exe
else
    SUFFIX :=
endif

NAME := renpy-update-tl
CLI := $(NAME)$(SUFFIX)
GUI := gui/$(NAME)-gui$(SUFFIX)
ZIP := $(NAME).zip

.PHONY: $(CLI) $(GUI)

all: $(ZIP)

clean:
	$(RM) $(CLI) $(GUI) $(ZIP)

$(CLI):
	$(DUB) build $(DUBFLAGS)

$(GUI):
	cd gui && $(DUB) build $(DUBFLAGS)

$(ZIP): $(CLI) $(GUI)
	@{ \
	set -eux; \
	t="`mktemp -d`"; \
	mkdir -- "$$t/$(NAME)"; \
	ln -- $(CLI) $(GUI) "$$t/$(NAME)/"; \
	p="$$PWD"; \
	cd -- "$$t"; \
	zip -q -r -FS "$$p/$(ZIP)" $(NAME)/; \
	cd /; \
	$(RM) -r -- "$$t"; \
	}
