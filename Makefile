.PHONY: start stop build load save clean status help

# Default target
help:
	@echo "WinXP QEMU Docker Management"
	@echo "============================"
	@echo "make start    - Smart start (load backup -> build -> use existing)"
	@echo "make stop     - Stop all services"
	@echo "make build    - Build from source"
	@echo "make load     - Load from backup file"
	@echo "make save     - Save current image as backup"
	@echo "make clean    - Remove containers and images"
	@echo "make status   - Show running containers"
	@echo "make logs     - Show container logs"

# Smart startup with automatic fallback
start:
	@echo "=== Smart WinXP QEMU Startup ==="
	@if docker image inspect winxp-qemu-baked:latest >/dev/null 2>&1; then \
		echo "✅ Using existing image"; \
		docker-compose up -d; \
	elif [ -f winxp-qemu-baked.tar.gz ]; then \
		echo "📥 Loading from backup..."; \
		docker load < <(gunzip -c winxp-qemu-baked.tar.gz); \
		docker-compose up -d; \
	else \
		echo "🔨 Building from source..."; \
		$(MAKE) build; \
		echo "💾 Auto-saving backup for future use..."; \
		$(MAKE) save; \
	fi
	@echo "🌐 Access: http://localhost:8888 (password: password1)"

# Stop services
stop:
	docker-compose down

# Build from source
build:
	@echo "🔨 Building WinXP QEMU from source..."
	docker-compose build --platform linux/amd64
	docker tag winxp-qemu-winxp-qemu:latest winxp-qemu-baked:latest
	docker-compose up -d
	@echo "✅ Build complete and tagged as winxp-qemu-baked:latest"

# Load from backup
load:
	@if [ -f winxp-qemu-baked.tar.gz ]; then \
		echo "📥 Loading image from backup..."; \
		docker load < <(gunzip -c winxp-qemu-baked.tar.gz); \
		echo "✅ Image loaded successfully"; \
	else \
		echo "❌ Backup file winxp-qemu-baked.tar.gz not found"; \
		exit 1; \
	fi

# Save current image as backup
save:
	@echo "💾 Saving current image as backup..."
	@if docker image inspect winxp-qemu-winxp-qemu:latest >/dev/null 2>&1; then \
		docker save winxp-qemu-winxp-qemu:latest | gzip > winxp-qemu-baked.tar.gz; \
		echo "✅ Backup saved: winxp-qemu-baked.tar.gz"; \
		ls -lh winxp-qemu-baked.tar.gz; \
	else \
		echo "❌ Image winxp-qemu-winxp-qemu:latest not found"; \
		exit 1; \
	fi

# Show status
status:
	@echo "=== Docker Images ==="
	@docker images | grep -E "(winxp-qemu|REPOSITORY)"
	@echo ""
	@echo "=== Running Containers ==="
	@docker-compose ps

# Show logs
logs:
	docker-compose logs -f

# Clean up
clean:
	@echo "🧹 Cleaning up..."
	docker-compose down
	docker rmi winxp-qemu-winxp-qemu:latest winxp-qemu-baked:latest 2>/dev/null || true
	@echo "✅ Cleanup complete"

# Install Windows XP (helper target)
install-xp:
	@echo "🪟 Starting Windows XP installation..."
	docker exec -it winxp-qemu-winxp-qemu-1 /root/install-xp.sh 