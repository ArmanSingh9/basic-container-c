#!/bin/bash

echo "==========================================="
echo "   🚀 BasicContainer Online Deployment"
echo "==========================================="

# Exit on any error
set -e

# 1. Check if we have sudo privileges
if ! command -v sudo >/dev/null 2>&1; then
    echo "[!] sudo not found. Trying without sudo (might fail if not root)..."
    SUDO=""
else
    SUDO="sudo"
fi

# 2. Install dependencies (assuming Debian/Ubuntu based host like Codespaces or EC2)
echo "📦 Installing system dependencies..."
$SUDO apt-get update
$SUDO apt-get install -y gcc make build-essential

# 3. Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install

# 4. Setup the rootfs for the container
echo "📁 Setting up isolated root filesystem (rootfs)..."
$SUDO bash setup_rootfs.sh

# 5. Compile the C container
echo "🔨 Compiling basic-container..."
make clean
make

echo "✅ Build complete!"
echo "🌐 Starting the web dashboard..."

# 6. Start the server
node server.js
