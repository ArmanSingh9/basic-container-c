# Project Report — Basic Container System

**Project Title:** Develop a Basic Container System similar to Docker
**Subject:** Operating Systems
**Language:** C (Linux System Calls)

---

## 1. Project Overview

Containers are a fundamental technology in modern software deployment, with Docker being the most popular example. At their core, containers use Linux kernel features — specifically namespaces and control groups — to isolate processes from one another and from the host system.

This project implements a basic container system in C that demonstrates the same core mechanisms that Docker and other container runtimes rely on. The container binary can launch isolated processes with their own PID namespace (so the process sees itself as PID 1), their own UTS namespace (so it can have a custom hostname), and a chroot-isolated filesystem (so it sees a completely different root directory).

The project uses only standard Linux system calls: `clone()` for creating the containerized process with new namespaces, `chroot()` for filesystem isolation, `sethostname()` for hostname isolation, and `execvp()` for launching the target command inside the container. This demonstrates that containers are not virtual machines — they are just processes with restricted views of the system, achieved through OS-level features.

---

## 2. Module Breakdown

### Module 1: Process Creation (`clone()`)
The `main()` function allocates a stack for the child process and calls `clone()` with namespace flags. Unlike `fork()`, `clone()` allows precise control over what the child shares with the parent. By passing `CLONE_NEWPID | CLONE_NEWUTS`, we create a child that lives in its own PID and UTS namespace.

### Module 2: PID Namespace Isolation
When `CLONE_NEWPID` is passed to `clone()`, the child process gets a fresh PID namespace. From inside this namespace, the child sees itself as PID 1 (like the init process on a real system). Any child processes it spawns also get low PIDs. The host can still see the container's real PID, but the container cannot see host processes.

### Module 3: UTS Namespace Isolation
The UTS (UNIX Time-sharing System) namespace controls the hostname and domain name. By passing `CLONE_NEWUTS`, the container gets its own hostname context. The `setup_hostname()` function calls `sethostname("my-container", ...)` inside this namespace. The host's hostname remains completely unchanged.

### Module 4: Filesystem Isolation (`chroot()`)
The `setup_filesystem()` function calls `chroot("./rootfs")` which changes the root directory for the container process. After this call, any path starting with `/` refers to paths inside `./rootfs`. The container cannot access files outside this directory tree. This is a key security and isolation mechanism.

### Module 5: Rootfs Setup (`setup_rootfs.sh`)
A shell script creates the minimal filesystem that the container needs. It copies `bash`, `ls`, `echo`, `cat`, and `pwd` binaries into `rootfs/bin/`. Critically, it also uses `ldd` to find and copy all shared libraries these binaries depend on (like `libc.so`, `libreadline.so`). Without the libraries, the binaries would fail to execute.

### Module 6: Command Execution (`execvp()`)
After setting up the namespace and filesystem, `execvp()` replaces the container process image with the requested command (e.g., `/bin/bash`). The `execvp()` variant searches PATH and accepts an array of arguments, making it suitable for running arbitrary commands.

---

## 3. Functionalities

- **Container launch:** `sudo ./container run <command>` starts an isolated container
- **PID isolation:** the process inside the container sees itself as PID 1
- **Custom hostname:** the container has hostname `my-container`, independent of the host
- **Filesystem isolation:** the container sees only `./rootfs` as its root filesystem
- **Interactive shell:** `sudo ./container run /bin/bash` opens a bash shell inside the container
- **Direct command execution:** any binary in `rootfs/bin/` can be run (ls, echo, cat, pwd)
- **Proper exit handling:** the host waits for the container and reports its exit code
- **Informative logging:** clear messages show what each step is doing

---

## 4. Technology Used

| Technology | Purpose |
|-----------|---------|
| **C Language** | Core implementation language |
| `clone()` system call | Create process with new namespaces (Linux-specific) |
| `CLONE_NEWPID` flag | Isolate PID namespace |
| `CLONE_NEWUTS` flag | Isolate hostname namespace |
| `chroot()` system call | Isolate filesystem view |
| `sethostname()` | Set custom hostname inside UTS namespace |
| `execvp()` | Execute command inside container |
| `waitpid()` | Wait for container process to exit |
| `ldd` utility | Identify shared library dependencies |
| **GCC** | Compile the C code |
| **Bash** | Write the rootfs setup script |
| **Linux kernel** | Provides namespace and chroot infrastructure |

---

## 5. Conclusion

This project successfully demonstrates the core mechanisms behind Linux container technology. By using `clone()` with `CLONE_NEWPID` and `CLONE_NEWUTS`, combined with `chroot()`, we created a process that is isolated from the host in terms of its PID namespace, hostname, and visible filesystem — exactly the foundational principles behind Docker containers.

The implementation shows that containers are fundamentally a Linux kernel feature, not a virtualization technology. The container shares the host kernel but has a restricted view of resources. This is what makes containers lightweight compared to virtual machines: there is no hypervisor, no separate OS kernel, and almost zero startup overhead.

The project deepened understanding of key OS concepts: process creation, namespaces, filesystem hierarchy, system calls, and how the kernel separates user-space views of resources.

---

## 6. Future Scope

1. **Network namespace (`CLONE_NEWNET`):** Give the container its own network interfaces, enabling network isolation similar to Docker's bridge networking.

2. **Mount namespace (`CLONE_NEWNS`):** Allow mounting `/proc` inside the container so that tools like `ps` work correctly.

3. **Control Groups (cgroups):** Limit the container's CPU, memory, and disk I/O usage — a key Docker feature for resource management.

4. **User namespace (`CLONE_NEWUSER`):** Map the container's root user to an unprivileged host user, removing the need for `sudo`.

5. **Container image layers:** Implement a basic overlay filesystem or copy-on-write mechanism to layer container images, similar to Docker's layered image system.

6. **Port forwarding:** Add simple iptables rules to forward host ports to container services.

7. **Container networking with veth pairs:** Create virtual Ethernet pair interfaces to connect the container to the host network.

8. **Multiple containers:** Manage multiple containers simultaneously with unique names and PIDs, similar to `docker ps`.

---

## 10 Viva Questions with Answers

**Q1. What is a Linux namespace and how is it used in this project?**

A namespace is a Linux kernel feature that wraps a global system resource in an abstraction so that processes within the namespace have their own isolated instance of that resource. In this project, we use `CLONE_NEWPID` to create an isolated PID namespace (the container sees itself as PID 1) and `CLONE_NEWUTS` to create an isolated UTS namespace (the container has its own hostname). Namespaces are the fundamental building block of container isolation.

---

**Q2. What is the difference between `fork()` and `clone()`?**

`fork()` creates a child process that is an exact copy of the parent — it always shares the same namespace context. `clone()` is a more general system call that lets you specify exactly what the child should share with the parent, using flags like `CLONE_NEWPID`, `CLONE_NEWUTS`, `CLONE_NEWNET`, etc. `clone()` also requires you to provide a separate stack for the child, since unlike `fork()`, it doesn't copy the parent's stack. Docker and all modern container runtimes use `clone()` under the hood.

---

**Q3. What does `chroot()` do and why is it important for containers?**

`chroot()` changes the apparent root directory (`/`) for the calling process and its children. After `chroot("./rootfs")` is called, any path starting with `/` is resolved relative to `./rootfs`. The process cannot access files outside that directory tree. This provides filesystem isolation — the container cannot read the host's `/etc/passwd`, `/home`, or other sensitive files. It is a lightweight alternative to a full virtual machine's isolated disk.

---

**Q4. Why do we need to copy shared libraries (using `ldd`) into the rootfs?**

When a binary like `bash` is compiled, it is typically dynamically linked — it expects to load shared libraries (like `libc.so.6`) at runtime from standard paths like `/lib` or `/usr/lib`. After `chroot()`, the process's `/lib` becomes `rootfs/lib`. If the libraries are not there, the dynamic linker (`ld-linux.so`) cannot find them and the binary fails to start with "No such file or directory". The `ldd` command lists exactly which libraries a binary needs, so we can copy them into the rootfs.

---

**Q5. What is a PID namespace and what does it mean to be PID 1 inside a container?**

A PID namespace isolates the process ID number space. Processes inside a new PID namespace get their own numbering starting from PID 1. The first process in the namespace (created by `clone()`) is PID 1 — equivalent to `init`/`systemd` on a real system. From inside the container, you cannot see host processes (they have PIDs in the host namespace, invisible from inside). However, the host can still see the container process with its real host PID. This is why `ps aux` inside a container shows far fewer processes than on the host.

---

**Q6. What is the UTS namespace and why would a container need its own hostname?**

UTS stands for UNIX Time-sharing System. The UTS namespace controls the system's hostname and NIS domain name. Containers need their own hostname for several reasons: so that log messages can be attributed to a specific container, so that applications that use the hostname for service discovery work correctly, and for isolation — you don't want a process inside a container to be able to change the host's hostname. With `CLONE_NEWUTS`, a call to `sethostname()` inside the container only affects the container's UTS namespace, not the host.

---

**Q7. Why does the program need to be run with `sudo`?**

Creating new namespaces with `CLONE_NEWPID` and `CLONE_NEWUTS` requires the `CAP_SYS_ADMIN` capability, which is only available to the root user by default. Similarly, `chroot()` requires root privileges. In production container runtimes like Docker, user namespaces (`CLONE_NEWUSER`) are used to map a container root user to an unprivileged host user, allowing rootless containers. This project uses the simpler approach of running as root directly.

---

**Q8. What is `execvp()` and why use it instead of `system()`?**

`execvp()` replaces the current process image with a new program. The `v` means arguments are passed as an array (vector), and the `p` means the PATH environment variable is searched to find the binary. After `execvp()` succeeds, the original code never runs again — the process IS now the new program. We use it instead of `system()` because `system()` spawns a shell which adds overhead, is a security concern, and doesn't give us direct control over the process. `execvp()` is the Unix-standard way to launch a program as a direct child.

---

**Q9. What is the difference between a container and a virtual machine?**

A virtual machine (VM) virtualizes physical hardware. It runs a complete guest OS with its own kernel on top of a hypervisor. This is heavyweight: each VM uses GBs of RAM and takes minutes to start. A container, by contrast, shares the host kernel. It uses Linux namespaces to give the illusion of isolation and cgroups to limit resources, but no second kernel runs. Containers start in milliseconds, use MBs of memory, and are much more efficient. The tradeoff is weaker isolation: a kernel vulnerability affects all containers on the host.

---

**Q10. What additional namespaces would you add to make this a more complete container runtime?**

The most important additions would be:
- **`CLONE_NEWNET`** (network namespace): give the container its own network interfaces. Currently our container shares the host network.
- **`CLONE_NEWNS`** (mount namespace): allow mounting `/proc` inside the container so `ps` and other proc-based tools work. Currently `ps aux` inside the container may not work correctly.
- **`CLONE_NEWUSER`** (user namespace): map container root (UID 0) to an unprivileged host UID, enabling rootless containers.
- **`CLONE_NEWIPC`** (IPC namespace): isolate System V IPC and POSIX message queues.
- **cgroups** (not a namespace, but a complementary feature): limit CPU, memory, and I/O usage per container.
