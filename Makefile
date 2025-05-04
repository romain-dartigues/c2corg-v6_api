# Make does not offer a recursive wildcard function, so here's one:
rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

PATH := .venv/bin:.venv/Scripts:${PATH}
TEMPLATE_FILES_IN := $(wildcard *.in) $(call rwildcard,*/,*.in)
TEMPLATE_FILES := $(TEMPLATE_FILES_IN:.in=)

ENV_FILES = config/env.default config/env.dev $(wildcard config/env.local)

SRC_DIRS = c2corg_api es_migration

PY_FILES := $(call rwildcard,$(SRC_DIRS)/,*.py)

DOCKER_COMPOSE = docker compose
DOCKER_EXEC = $(DOCKER_COMPOSE) exec
DB_EXEC = $(DOCKER_EXEC) -u postgres -T postgresql

help:
	@echo "Usage: make <target>"
	@echo
	@echo "Main targets:"
	@echo
	@echo "- bootstrap"				Bootstraps the project for the first time
	@echo "- run-syncer				Run the ElasticSearch syncer script."
	@echo "- run-background-jobs"	Run the background jobs
	@echo
	@echo "- test					Run the unit tests"
	@echo "- lint					Run flake8 checker on the Python code"
	@echo
	@echo "Secondary targets:"
	@echo
	@echo "- start"					Start the docker containers
	@echo "- stop"					Stop the docker containers
	@echo "- serve"					Start the Python webserver
	@echo
	@echo "- init-database" 		Initialize the dev database
	@echo "- init-test-database" 	Initialize the test database
	@echo "- init-elastic"			Initialize the elasticsearch index
	@echo "- flush-redis			Clear the Redis cache"
	@echo
	@echo "- loadenv				Replace the env vars in the .in templates"


.PHONY: bootstrap
bootstrap: start install load-env init-database init-test-database init-elastic

.PHONY: start
start:
	$(DOCKER_COMPOSE) up -d

.PHONY: stop
stop:
	$(DOCKER_COMPOSE) stop

.PHONY: serve
serve: venv
	pserve development.ini --reload

.PHONY: lint
lint: venv
	flake8 $(SRC_DIRS)
	@echo "Wonderful, python style is Ok!"

.coverage: venv $(PY_FILES)
	pytest

.PHONY: coverage
coverage: .coverage
	coverage report $(OPTS)

htmlcov/index.html: .coverage
	 coverage html

.PHONY: test
test: venv
	pytest $(OPTS)

.PHONY: init-database
init-database: venv
	$(DB_EXEC) /v6_api/scripts/database/create_schema.sh
	initialize_c2corg_api_db development.ini

.PHONY: init-test-database
init-test-database:
	$(DB_EXEC) /v6_api/scripts/database/create_test_schema.sh

.PHONY: init-elastic
init-elastic: venv
	fill_es_index development.ini

.PHONY: run-syncer
run-syncer: venv
	python3 c2corg_api/scripts/es/syncer.py development.ini

.PHONY: run-background-jobs
run-background-jobs: venv
	python3 c2corg_api/scripts/jobs/scheduler.py development.ini

.PHONY: flush-redis
flush-redis: venv
	python3 c2corg_api/scripts/redis-flushdb.py development.ini

.PHONY: load-env
load-env: venv $(TEMPLATE_FILES)

development.ini: common.ini
test.ini: common.ini

%: %.in venv
	@env_replace $(if $(ENV_FILES),--env-file $(ENV_FILES),) -i $< -o $@

.venv/pyvenv.cfg: pyproject.toml
	@if type uv >/dev/null 2>&1;\
	then uv venv -q && uv pip install --all-extras -e . -r pyproject.toml;\
	else python3 -m venv .venv;pip install -e .[dev];\
	fi

.PHONY: venv
venv: .venv/pyvenv.cfg
