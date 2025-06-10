ZIG ?= zig

.PHONY: build test clean install

build:
	$(ZIG) build

test:
	$(ZIG) build test

clean:
	rm -rf zig-out zig-cache

all: build test

help:
	@echo "Available targets:"
	@echo "  build   - Build the library"
	@echo "  test    - Run tests"
	@echo "  clean   - Remove build artifacts"
	@echo "  all     - Build and test"
