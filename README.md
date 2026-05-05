# 🐳 BasicContainer — A Docker-like Container in C

> **B.Tech CSE Operating Systems Project**
> Demonstrates: `clone()`, PID namespaces, UTS namespaces, `chroot()`, process isolation

This project builds a simple container runtime using Linux system calls and connects it to a web-based dashboard where you can run 40 different Linux commands inside the isolated container.

---

## 🛠️ Step-by-Step Guide to Run the Project

Because this project uses Linux-specific OS concepts like `clone()` and namespaces, **you cannot run the backend natively on Windows**. You must use WSL (Windows Subsystem for Linux) or a VS Code Dev Container.

Assuming you have WSL installed on your Windows machine, follow these steps exactly:

### Step 1: Open a WSL Terminal
Do not use the standard Windows PowerShell. Open a WSL terminal. You can do this by running `wsl` in PowerShell, or by opening a new "Ubuntu" (or your WSL distro) tab in Windows Terminal.

Navigate to your project directory:
```bash
# Example (adjust the path to where your project is)
cd /mnt/c/Users/arman/Downloads/basic-container-c
```

### Step 2: Compile the C Program
Compile the `container.c` binary by running `make`.
```bash
make
```
*Expected Output:*
`[BUILD] Done! Binary: ./container`

### Step 3: Create the Container Filesystem
The container needs its own isolated mini-filesystem (`rootfs`). The setup script copies all 40 required commands (like `ls`, `cat`, `grep`) and their dependencies into this folder.

Run the setup script with `sudo` (since setting up device nodes and mounting `/proc` requires root privileges):
```bash
sudo bash setup_rootfs.sh
```
*Expected Output:*
You will see steps `[1]` through `[5]` completing successfully.

### Step 4: Install Node.js Dependencies
The web dashboard relies on Node.js and Express. Install the required packages:
```bash
npm install
```

### Step 5: Start the Web Server
Start the Node.js server to bridge the web dashboard to the C container.
```bash
node server.js
```
*Expected Output:*
```
  🟢 Server running at http://localhost:3000
```

### Step 6: Open the Dashboard
Open your web browser (Chrome, Edge, etc.) on Windows and go to:
**👉 http://localhost:3000**

You can now type commands like `ls -la`, `whoami`, `ps`, and `df` into the terminal UI!

---

## 💡 Troubleshooting

- **Error: `EADDRINUSE: address already in use :::3000`**
  This means the Node server is already running in the background. You can just open `http://localhost:3000`. If you want to stop the background process, close your terminals or run `killall node` in WSL.
- **Error: `sudo ./container: command not found`**
  You forgot to run `make` (Step 2) to compile the C binary.
- **Error: `chroot() failed`**
  You forgot to run `sudo bash setup_rootfs.sh` (Step 3).

---

## 🧠 OS Concepts Demonstrated
1. **`clone()`**: Creates the container process. Unlike `fork()`, we pass flags to create new namespaces.
2. **PID Namespace (`CLONE_NEWPID`)**: The process inside the container sees itself as PID 1.
3. **UTS Namespace (`CLONE_NEWUTS`)**: The container gets its own isolated hostname (`my-container`).
4. **Filesystem Isolation (`chroot()`)**: The container is restricted to the `./rootfs` directory. It cannot access the host's real root filesystem.
Update 1
Another update
