.PHONY: build test lint lint-arch lint-md lint-all clean fmt

# Optional: VERSION=1.0.2 make build — embeds into Sources/zenv/Zenv.swift first.
VERSION ?=

build:
	mkdir -p dist
ifneq ($(VERSION),)
	@bash scripts/embed-version.sh "$(VERSION)"
endif
	swift build -c release
	cp -f .build/release/zenv dist/zenv

test:
	swift test

lint:
	swift build --build-tests

lint-arch:
	@bash scripts/lint-deps.sh

lint-md:
	@bash scripts/lint-md.sh

lint-all: lint lint-arch lint-md

fmt:
	swift format --in-place --recursive Sources Tests Package.swift

clean:
	rm -rf dist/ .build/
