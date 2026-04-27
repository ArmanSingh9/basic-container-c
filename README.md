# 🐳 BasicContainer — A Docker-like Container in C

> **B.Tech CSE Operating Systems Project**
> Demonstrates: `clone()`, PID namespaces, UTS namespaces, `chroot()`, process isolation

---

## Project Structure

```
basic-container/
├── src/
│   └── container.c       ← Main C source code
├── rootfs/               ← Mini filesystem (created by setup script)
│   ├── bin/              ← bash, ls, echo, cat, pwd
│   ├── lib/              ← shared libraries (auto-copied)
│   ├── etc/              ← passwd, hostname, os-release
│   ├── proc/             ← mount point for /proc
│   └── dev/              ← device nodes
├── Makefile              ← Build automation
├── setup_rootfs.sh       ← Creates the mini filesystem
└── README.md             ← This file
```

---

## Step 1 — Install Required Packages

```bash
sudo apt update
sudo apt install -y gcc make build-essential
```

Verify gcc is installed:
```bash
gcc --version
```

---

## Step 2 — Clone / Create the Project

If you have the files already, navigate to the folder:
```bash
cd basic-container
```

---

## Step 3 — Create the Mini Filesystem

This script copies `bash`, `ls`, `echo`, `cat`, `pwd` and all their libraries into `./rootfs`:

```bash
sudo bash setup_rootfs.sh
```

Expected output: You'll see directories being created and libraries being copied.

---

## Step 4 — Compile the Container

```bash
make
```

OR manually:
```bash
gcc -Wall -Wextra -D_GNU_SOURCE -std=c99 -o container src/container.c
```

Expected output:
```
[BUILD] Compiling container...
[BUILD] Done! Binary: ./container
```

---

## Step 5 — Run the Container

### Run bash (interactive shell inside container):
```bash
sudo ./container run /bin/bash
```

You'll see:
```
  ╔══════════════════════════════════════╗
  ║   Basic Container (Docker-like)      ║
  ║   OS Project — B.Tech CSE            ║
  ╚══════════════════════════════════════╝

[HOST]  Starting container...
[HOST]  Command: /bin/bash
[CONTAINER] PID inside container: 1
[CONTAINER] Hostname set to: my-container
[CONTAINER] Filesystem isolated to: ./rootfs
[CONTAINER] Executing: /bin/bash

root@my-container:/#
```

Inside the container, try:
```bash
hostname           # shows: my-container
ps aux             # shows only a few processes (isolated PID namespace)
ls /               # shows rootfs contents, NOT host /
cat /etc/os-release
pwd
exit
```

### Run ls directly:
```bash
sudo ./container run /bin/ls
```

### Run echo:
```bash
sudo ./container run /bin/echo "Hello from inside the container!"
```

---

## OS Concepts Demonstrated

| Concept | How it's used |
|---------|--------------|
| `fork()` / `clone()` | `clone()` creates the container process with namespace flags |
| PID Namespace | Container process sees itself as PID 1 |
| UTS Namespace | Container has its own hostname (`my-container`) |
| `chroot()` | Filesystem is isolated to `./rootfs` |
| `exec()` family | `execvp()` runs the command inside the container |
| `wait()` / `waitpid()` | Host waits for container to finish |

---

## Makefile Shortcuts

```bash
make              # compile
make setup-rootfs # create rootfs (needs sudo internally)
make run-bash     # sudo ./container run /bin/bash
make run-ls       # sudo ./container run /bin/ls
make run-echo     # sudo ./container run /bin/echo Hello
make clean        # remove binary
make help         # show all options
```

---

## Troubleshooting

**Error: `clone() failed: Operation not permitted`**
→ Run with `sudo`

**Error: `chroot() failed: No such file or directory`**
→ Run `sudo bash setup_rootfs.sh` first

**Error: `execvp('/bin/bash') failed`**
→ Check that `rootfs/bin/bash` exists: `ls rootfs/bin/`

**Bash prompt shows `bash-5.x$` instead of `root@my-container`**
→ That's normal if `/etc/passwd` wasn't set up. It still works perfectly.

---

## GitHub Suggested Repo Name

`basic-container-c`

### Suggested Commit Messages

1. `Initial commit: project structure and Makefile`
2. `Add container.c: clone() with PID and UTS namespace isolation`
3. `Add chroot() filesystem isolation to container_main()`
4. `Add setup_rootfs.sh to create mini filesystem with bash, ls, echo`
5. `Add library copying via ldd in setup_rootfs.sh`
6. `Add error handling and informative log messages`
7. `Add /etc/passwd, hostname, motd for realistic container environment`
8. `Add Makefile shortcuts: run-bash, run-ls, run-echo`
9. `Add README with full setup and run instructions`
10. `Final cleanup: comments, usage messages, project polish`
