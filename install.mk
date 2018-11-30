THIS_FILE := $(lastword $(MAKEFILE_LIST))
THIS_DIR := $(dir $(THIS_FILE))
RESOURCES_DIR := $(THIS_DIR)resources
ROTHENBERG_EXISTS = $(wildcard .rothenberg)

include $(RESOURCES_DIR)/rothenberg/utils.mk

PHP_BIN ?= bin/php
GIT_BIN ?= $(call locate-binary,git)
COMPOSER_BIN ?= bin/composer
COMPOSER_JSON_PATH ?= /src/composer.json

ifneq ("$(ROTHENBERG_EXISTS)","")
include $(ROTHENBERG_EXISTS)
endif

TARGET ?= app
SYMFONY_VERSION ?= "^3.4"

ifeq ($(filter $(TARGET),app bundle),)
$(error Target $(TARGET) is invalid!);
endif

.SILENT:

.SUFFIXES:

.DELETE_ON_ERROR:

.PRECIOUS: composer.json

# Implicit rules

rothenberg/%: $(RESOURCES_DIR)/rothenberg/% | rothenberg
	$(CP) $< $@

rothenberg/bin/%: $(RESOURCES_DIR)/rothenberg/bin/% | rothenberg/bin
	$(CP) $< $@

rothenberg/nginx/%: $(RESOURCES_DIR)/rothenberg/nginx/% | rothenberg/nginx
	$(CP) $< $@

src/AppBundle/Resources/config/%: | src/AppBundle/Resources/config
	$(CP) $(RESOURCES_DIR)/$@ $@

src/AppBundle/%: | src/AppBundle
	$(CP) $(RESOURCES_DIR)/$@ $@

app/config/%: | app/config
	$(CP) $(RESOURCES_DIR)/$@ $@

app/%: | app
	$(CP) $(RESOURCES_DIR)/$@ $@

web/%: | web
	$(CP) $(RESOURCES_DIR)/$@ $@

src/%: | src
	$(CP) $(RESOURCES_DIR)/$@ $@

tests/units/%: $(RESOURCES_DIR)/tests/units/% | tests/units
	$(CP) $< $@

rothenberg/php/%.ini: | rothenberg/php
	$(CP) $(RESOURCES_DIR)/$@ $@

.gitignore: $(RESOURCES_DIR)/git/ignore.$(TARGET)
	$(call merge-file,$@,$<)

.git%: $(RESOURCES_DIR)/git/%
	$(call merge-file,$@,$<)

bin/%: rothenberg/Makefile
	$(MAKE) -f $< $@

%: $(RESOURCES_DIR)/%
	$(CP) $< $@

gc/%:
	$(RM) $(patsubst gc/%,%,$@)

rothenberg rothenberg/bin rothenberg/nginx app src web tests/units rothenberg/php app/config src/AppBundle src/AppBundle/Resources/config:
	$(MKDIR) $@

# Install

.PHONY: install
install: $(THIS_FILE) Makefile install/docker install/symfony install/tests install/git install/check-style install/node gc
	echo "TARGET = $(TARGET)" > .rothenberg
ifneq ("$(ROTHENBERG_EXISTS)","")
	@printf "\n=> Norsys/rothenberg update done!\n"
else
	@printf "\n=> Norsys/rothenberg installation done!\n"
endif

## Make

Makefile: | rothenberg/Makefile
	$(CP) $(RESOURCES_DIR)/$@.$(TARGET) $@

rothenberg/Makefile: $(RESOURCES_DIR)/rothenberg/$(TARGET).mk rothenberg/common.mk
	$(CP) $< $@

rothenberg/common.mk: rothenberg/utils.mk

## Tests

.PHONY: install/tests
install/tests: install/tests/units

ifeq ($(TARGET),app)
install/tests: install/tests/functionals
endif

.PHONY: install/tests/units
install/tests/units: install/symfony .atoum.php tests/units/runner.php tests/units/Test.php tests/units/src/.gitkeep

.PHONY: install/tests/functionals
install/tests/functionals: install/symfony/app behat.yml

%/.gitkeep:
	$(MKDIR) $(dir $@)
	> $@

.atoum.php behat.yml:
	$(CP) $(RESOURCES_DIR)/$@ $@

## Check-style

.PHONY: install/check-style
install/check-style: check-style.xml

check-style.xml:
	$(CP) $(RESOURCES_DIR)/$@ $@

## Docker

.PHONY: install/docker
install/docker: docker-compose.yml docker-compose.override.yml rothenberg/.env.dist rothenberg/bin/docker-compose

docker-compose.yml: $(RESOURCES_DIR)/docker-compose.$(TARGET).yml
	$(CP) $< $@

docker-compose.override.yml:
	$(CP) $(RESOURCES_DIR)/$@ $@

rothenberg/.env.dist: $(RESOURCES_DIR)/rothenberg/.env.$(TARGET).dist | rothenberg
	$(CP) $< $@

ifeq ($(TARGET),app)
rothenberg/bin/docker-compose: rothenberg/nginx/default.conf rothenberg/docker-compose.rothenberg.yml
endif

## Symfony

.PHONY: install/symfony
install/symfony: install/php composer.json | src

.PHONY: install/symfony/app
install/symfony/app: app/console.php web/app.php web/apple-touch-icon.png web/favicon.ico web/robots.txt

composer.json: $(RESOURCES_DIR)/composer.json.php | $(PHP_BIN) $(COMPOSER_BIN)
	$(PHP_BIN) -d memory_limit=-1 -f $(RESOURCES_DIR)/composer.json.php -- $(COMPOSER_JSON_PATH) $(TARGET) $(SYMFONY_VERSION)
	export GIT_SSH_COMMAND="ssh -i $(SSH_KEY) -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" && $(PHP_BIN) -d memory_limit=-1 $(COMPOSER_BIN) update --lock --no-scripts --ignore-platform-reqs --no-suggest

ifeq ($(TARGET),app)
composer.json: app/console.php
endif

app/console.php: | $(RESOURCES_DIR)/app/console.php app/AppKernel.php app/autoload.php app/AppCache.php
	$(CP) $(RESOURCES_DIR)/$@ $@

app/AppKernel.php: | app/config/config.yml app/config/config_dev.yml app/config/config_prod.yml app/config/parameters.yml app/config/routing.yml app/config/routing_dev.yml app/config/security.yml src/AppBundle/AppBundle.php
	$(CP) $(RESOURCES_DIR)/$@ $@

src/AppBundle/AppBundle.php: | src/AppBundle/Resources/config/routing.yml
	$(CP) $(RESOURCES_DIR)/$@ $@

## Git

.PHONY: install/git
install/git: .git .gitattributes .gitignore rothenberg/bin/pre-commit

.git:
	$(GIT_BIN) init

## PHP

.PHONY: install/php
install/php: install/docker install/php/composer install/php/cli

ifeq ($(TARGET),app)
install/php: install/php/fpm
endif

.PHONY: install/php/cli
install/php/cli: rothenberg/php/cli.ini rothenberg/bin/bin.tpl rothenberg/bin/php

.PHONY: install/php/fpm
install/php/fpm: rothenberg/php/fpm.ini

.PHONY: install/php/composer
install/php/composer: rothenberg/bin/composer

rothenberg/bin/composer: rothenberg/bin/docker-compose

## Node

.PHONY: install/node
install/node:

ifeq ($(TARGET),app)
rothenberg/bin/docker-compose: rothenberg/bin/node rothenberg/bin/npm
endif

# GC

.PHONY: gc
gc: gc/rothenberg/php/cli gc/rothenberg/php/fpm gc/rothenberg/docker gc/rothenberg/.rothenberg
