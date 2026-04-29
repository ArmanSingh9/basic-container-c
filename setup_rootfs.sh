#!/bin/bash

# setup_rootfs.sh — Creates the mini filesystem for the container
# This script must be run as root (or with sudo)

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo bash setup_rootfs.sh)"
  exit 1
fi

ROOTFS="./rootfs"

echo "[1] Cleaning up old rootfs..."
if mountpoint -q "$ROOTFS/proc"; then
  umount "$ROOTFS/proc"
fi
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

echo "[2] Creating base directories..."
mkdir -p "$ROOTFS"/{bin,lib,lib64,etc,proc,dev,usr/bin,usr/lib,tmp,root}

# Set up some basic files
echo "root:x:0:0:root:/root:/bin/bash" > "$ROOTFS/etc/passwd"
echo "my-container" > "$ROOTFS/etc/hostname"
echo 'PRETTY_NAME="BasicContainer Linux"' > "$ROOTFS/etc/os-release"

echo "[3] Copying required binaries..."

# List of all requested commands that have independent binaries
# Note: cd and history are shell built-ins (handled by bash)
BINS=(
  "bash" "ls" "mkdir" "rmdir" "touch" "rm" "cp" "mv" "cat" "echo" "pwd" 
  "clear" "whoami" "date" "uname" "hostname" "head" "tail" "wc" "sort" 
  "uniq" "grep" "find" "chmod" "du" "df" "ps" "env" "printenv" "which" 
  "dirname" "basename" "sleep" "cal" "uptime" "id" "yes"
)

# Function to find and copy a binary and its shared libraries
copy_bin_and_libs() {
  local cmd=$1
  
  # Find the binary path (e.g., /bin/ls or /usr/bin/find)
  local bin_path
  bin_path=$(which "$cmd" 2>/dev/null)
  
  if [ -z "$bin_path" ]; then
    echo "  Warning: '$cmd' not found on host system."
    return
  fi

  # Copy the binary
  cp "$bin_path" "$ROOTFS/bin/"

  # Use ldd to find all shared libraries needed by the binary
  # Example output of ldd:
  #   linux-vdso.so.1 (0x00007ffc9f3e4000)
  #   libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f5b8c600000)
  #   /lib64/ld-linux-x86-64.so.2 (0x00007f5b8c9f0000)
  
  local libs
  libs=$(ldd "$bin_path" 2>/dev/null | grep -o '/[^ ]*' | grep -v 'linux-vdso')

  for lib in $libs; do
    if [ -f "$lib" ]; then
      # Create the directory structure in rootfs (e.g., /lib/x86_64-linux-gnu)
      local lib_dir
      lib_dir=$(dirname "$lib")
      mkdir -p "$ROOTFS$lib_dir"
      
      # Copy the library if it doesn't already exist in rootfs
      if [ ! -f "$ROOTFS$lib" ]; then
        cp "$lib" "$ROOTFS$lib"
      fi
    fi
  done
}

# Copy each binary and its dependencies
for cmd in "${BINS[@]}"; do
  copy_bin_and_libs "$cmd"
done

# We also need to copy some terminfo data for 'clear' to work
if [ -d "/lib/terminfo" ]; then
  cp -r /lib/terminfo "$ROOTFS/lib/"
elif [ -d "/usr/share/terminfo" ]; then
  mkdir -p "$ROOTFS/usr/share"
  cp -r /usr/share/terminfo "$ROOTFS/usr/share/"
fi

echo "[4] Setting up device nodes and proc..."
# Some commands like 'ps' need /proc. We mount it from the host to the rootfs.
# We do a bind mount of the host's /proc to rootfs/proc
if mountpoint -q "$ROOTFS/proc"; then
  umount "$ROOTFS/proc"
fi
mount -t proc none "$ROOTFS/proc"

echo "[5] DONE! The mini filesystem is ready at ./rootfs"
