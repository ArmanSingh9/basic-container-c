# ─────────────────────────────────────────────────────────────
#  Makefile — Basic Container (OS Project)
# ─────────────────────────────────────────────────────────────

CC       = gcc
CFLAGS   = -Wall -Wextra -D_GNU_SOURCE -std=c99
TARGET   = container
SRC      = src/container.c
ROOTFS   = ./rootfs

.PHONY: all clean setup-rootfs run-bash run-ls help

# ── Default target: compile ───────────────────────────────────
all: $(TARGET)

$(TARGET): $(SRC)
	@echo "[BUILD] Compiling $(TARGET)..."
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)
	@echo "[BUILD] Done! Binary: ./$(TARGET)"

# ── Setup the mini root filesystem ───────────────────────────
setup-rootfs:
	@echo "[SETUP] Creating rootfs directory structure..."
	@bash setup_rootfs.sh
	@echo "[SETUP] rootfs is ready!"

# ── Quick run targets ─────────────────────────────────────────
run-bash: $(TARGET)
	@echo "[RUN] Starting container with /bin/bash"
	sudo ./$(TARGET) run /bin/bash

run-ls: $(TARGET)
	@echo "[RUN] Running ls inside container"
	sudo ./$(TARGET) run /bin/ls

run-echo: $(TARGET)
	@echo "[RUN] Running echo inside container"
	sudo ./$(TARGET) run /bin/echo "Hello from inside the container!"

# ── Clean build artifacts ─────────────────────────────────────
clean:
	@echo "[CLEAN] Removing binary..."
	rm -f $(TARGET)
	@echo "[CLEAN] Done."

# ── Help ──────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Available targets:"
	@echo "  make              → Compile the container binary"
	@echo "  make setup-rootfs → Create the mini filesystem"
	@echo "  make run-bash     → Run bash inside container"
	@echo "  make run-ls       → Run ls inside container"
	@echo "  make run-echo     → Run echo inside container"
	@echo "  make clean        → Remove compiled binary"
	@echo ""
	@echo "Manual usage:"
	@echo "  sudo ./container run /bin/bash"
	@echo "  sudo ./container run /bin/ls"
	@echo "  sudo ./container run /bin/echo Hello"
	@echo ""
