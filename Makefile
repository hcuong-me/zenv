.PHONY: build test lint lint-arch lint-md lint-all clean fmt

build:
	mkdir -p dist
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
