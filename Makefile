# PhoenixBoot Makefile
# Convenience commands for container-based development

.PHONY: help build test installer runtime tui clean all

help: ## Show this help message
	@echo "PhoenixBoot Container Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build all container images
	docker compose build

build-image: ## Build specific container (e.g., make build-image SERVICE=build)
	docker compose build $(SERVICE)

run-build: ## Run build container
	docker compose --profile build up

run-test: ## Run test container
	docker compose --profile test up

run-installer: ## Run installer container
	docker compose --profile installer up

run-runtime: ## Run runtime container
	docker compose --profile runtime up

run-tui: ## Run TUI container (interactive)
	docker compose --profile tui up

run-all: ## Run all containers
	docker compose --profile all up

clean: ## Clean up containers and volumes
	docker compose down -v

clean-images: ## Remove PhoenixBoot container images
	docker rmi phoenixboot-build phoenixboot-test phoenixboot-installer phoenixboot-runtime phoenixboot-tui || true

rebuild: clean-images build ## Rebuild all containers from scratch

shell-build: ## Open shell in build container
	docker compose run --rm phoenixboot-build bash

shell-test: ## Open shell in test container
	docker compose run --rm phoenixboot-test bash

shell-tui: ## Open shell in TUI container
	docker compose run --rm phoenixboot-tui bash

logs: ## Show container logs
	docker compose logs -f

ps: ## Show running containers
	docker compose ps

validate: ## Validate docker-compose configuration
	docker compose config

# Direct execution (non-containerized)
.PHONY: direct-build direct-test direct-tui

direct-build: ## Run build directly (no container)
	./pf.py build-build

direct-test: ## Run tests directly (no container)
	./pf.py test-qemu

direct-tui: ## Run TUI directly (no container)
	./phoenixboot-tui.sh
