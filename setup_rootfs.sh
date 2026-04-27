#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  setup_rootfs.sh
#  Creates a minimal root filesystem for our container.
#  Copies: bash, ls, echo + all their shared libraries.
# ─────────────────────────────────────────────────────────────

set -e   # exit on any error

ROOTFS="./rootfs"

# ── Colors for pretty output ─────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[SETUP]${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}   $1"; }
err()  { echo -e "${RED}[ERROR]${NC}  $1"; exit 1; }

# ── Step 1: Create directory tree ────────────────────────────
log "Creating directory structure in $ROOTFS ..."
mkdir -p "$ROOTFS"/{bin,lib,lib64,lib/x86_64-linux-gnu,usr/bin,usr/lib,proc,sys,dev,tmp,root,etc}
log "Directories created."

# ── Step 2: Helper to copy a binary + its libraries ──────────
copy_binary_with_libs() {
    local bin_path="$1"
    local bin_name
    bin_name=$(basename "$bin_path")

    # Find the actual binary (resolve if it's a shell built-in alias)
    local real_path
    real_path=$(which "$bin_name" 2>/dev/null || echo "$bin_path")

    if [ ! -f "$real_path" ]; then
        warn "Binary not found: $real_path — skipping."
        return
    fi

    log "Copying binary: $bin_name (from $real_path)"
    cp "$real_path" "$ROOTFS/bin/$bin_name"
    chmod +x "$ROOTFS/bin/$bin_name"

    # Copy all shared libraries using ldd
    log "Copying libraries for $bin_name ..."
    ldd "$real_path" 2>/dev/null | while read -r line; do
        # ldd output format: "libname.so => /path/to/lib (0xaddr)"
        local lib_path
        lib_path=$(echo "$line" | awk '{
            for (i=1; i<=NF; i++) {
                if ($i ~ /^\//) { print $i; break }
            }
        }')

        if [ -n "$lib_path" ] && [ -f "$lib_path" ]; then
            local lib_dir
            lib_dir=$(dirname "$lib_path")
            mkdir -p "$ROOTFS$lib_dir"
            cp -n "$lib_path" "$ROOTFS$lib_dir/" 2>/dev/null || true
        fi
    done

    # Also handle the dynamic linker (ld-linux)
    local ld_path
    ld_path=$(ldd "$real_path" 2>/dev/null | grep "ld-linux\|ld-musl" | awk '{print $1}')
    if [ -n "$ld_path" ] && [ -f "$ld_path" ]; then
        local ld_dir
        ld_dir=$(dirname "$ld_path")
        mkdir -p "$ROOTFS$ld_dir"
        cp -n "$ld_path" "$ROOTFS$ld_dir/" 2>/dev/null || true
    fi
}

# ── Step 3: Copy required binaries ───────────────────────────
log "Setting up binaries..."

copy_binary_with_libs bash
copy_binary_with_libs ls
copy_binary_with_libs echo
copy_binary_with_libs cat
copy_binary_with_libs pwd

# ── Step 4: Create /etc/passwd (bash needs it for prompts) ───
log "Creating /etc/passwd ..."
cat > "$ROOTFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

# ── Step 5: Create /etc/hostname ─────────────────────────────
log "Creating /etc/hostname ..."
echo "my-container" > "$ROOTFS/etc/hostname"

# ── Step 6: Create a simple /etc/os-release ──────────────────
log "Creating /etc/os-release ..."
cat > "$ROOTFS/etc/os-release" << 'EOF'
NAME="BasicContainer"
VERSION="1.0"
ID=basiccontainer
PRETTY_NAME="BasicContainer 1.0 (OS Project)"
EOF

# ── Step 7: Create a welcome message ─────────────────────────
log "Creating /etc/motd ..."
cat > "$ROOTFS/etc/motd" << 'EOF'

  Welcome to BasicContainer!
  --------------------------
  You are inside an isolated container.
  PID namespace: isolated (you are PID 1 here)
  UTS namespace: isolated (custom hostname)
  Filesystem:    chroot-ed to ./rootfs

  Try: ls /    pwd    cat /etc/os-release
  Type 'exit' to leave the container.

EOF

# ── Step 8: Create basic /dev nodes ──────────────────────────
log "Creating basic /dev entries..."
# Only create if running as root
if [ "$(id -u)" = "0" ]; then
    mknod -m 666 "$ROOTFS/dev/null"    c 1 3 2>/dev/null || true
    mknod -m 666 "$ROOTFS/dev/zero"    c 1 5 2>/dev/null || true
    mknod -m 666 "$ROOTFS/dev/random"  c 1 8 2>/dev/null || true
    mknod -m 666 "$ROOTFS/dev/urandom" c 1 9 2>/dev/null || true
    mknod -m 620 "$ROOTFS/dev/tty"     c 5 0 2>/dev/null || true
    log "Device nodes created."
else
    warn "Not running as root — skipping device node creation."
    warn "Run 'sudo bash setup_rootfs.sh' for full setup."
fi

# ── Step 9: Set /tmp permissions ─────────────────────────────
chmod 1777 "$ROOTFS/tmp"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  rootfs setup complete!${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
echo "  Contents of $ROOTFS:"
find "$ROOTFS" -maxdepth 2 -type d | sort | sed 's/^/    /'
echo ""
echo "  Binaries available inside container:"
ls "$ROOTFS/bin/" 2>/dev/null | sed 's/^/    /'
echo ""
