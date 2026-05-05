# ─────────────────────────────────────────────────────────────
#  Makefile — Basic Container (OS Project)
# ─────────────────────────────────────────────────────────────

# Compiler and build settings for the container runtime
CC       = gcc
CFLAGS   = -Wall -Wextra -D_GNU_SOURCE -std=c99
TARGET   = container
SRC      = src/container.c
ROOTFS   = ./rootfs

.PHONY: all clean setup-rootfs help

# ── Default target: compile ───────────────────────────────────
all: $(TARGET)

$(TARGET): $(SRC)
	@echo "[BUILD] Compiling $(TARGET)..."
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)
	@echo "[BUILD] Done! Binary: ./$(TARGET)"

# ── Setup the mini root filesystem ───────────────────────────
setup-rootfs:
	@echo "[SETUP] Creating rootfs directory structure..."
	@sudo bash setup_rootfs.sh
	@echo "[SETUP] rootfs is ready!"

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
	@echo "  make clean        → Remove compiled binary"
	@echo ""
