MIX ?= mix
NPM ?= npm

.PHONY: setup dev test ui sdk-build generator docs-strict validate docker-up docker-down

setup:
	$(MIX) deps.get
	cd apps/ts-sdk && $(NPM) install
	cd apps/ui && $(NPM) install

dev:
	$(MIX) run --no-halt

test:
	$(MIX) test

ui:
	cd apps/ui && $(NPM) run dev

sdk-build:
	cd apps/ts-sdk && $(NPM) run build

generator:
	python3 scripts/cathedral_generator.py --out generated

docs-strict:
	python3 scripts/check_docs_strict.py

validate:
	python3 scripts/validate_repo.py

docker-up:
	docker compose up --build

docker-down:
	docker compose down -v
