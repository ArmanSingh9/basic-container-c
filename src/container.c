
/*
 * basic-container: A minimal Docker-like container in C
 * Demonstrates: clone(), namespaces, chroot(), process isolation
 *
 * Author: B.Tech CSE OS Project
 * Concepts: PID namespace, UTS namespace, chroot, clone()
 *
 * Compile: gcc -Wall -Wextra -D_GNU_SOURCE -std=c99 -o container src/container.c
 * Run:     sudo ./container run /bin/bash
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sched.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <fcntl.h>
#include <errno.h>
#include <limits.h>

/* ─── Constants ──────────────────────────────────────── */
#define STACK_SIZE  (1024 * 1024)   /* 1 MB stack for child process */
#define ROOTFS_PATH "./rootfs"       /* path to our mini filesystem */
#define CONTAINER_HOSTNAME "my-container"

/* ─── Child process argument bundle ──────────────────── */
typedef struct {
    char **argv;   /* command + args to run inside container */
    int    argc;
} ChildArgs;

/* ─── Forward declarations ───────────────────────────── */
static int  container_main(void *arg);
static void setup_filesystem(void);
static void setup_hostname(void);
static void print_banner(void);
static void print_usage(const char *prog);

/* ═══════════════════════════════════════════════════════
 * main()
 * Parses arguments, allocates stack, and calls clone()
 * ═══════════════════════════════════════════════════════ */
int main(int argc, char *argv[])
{
    // print_banner();

    /* ── Argument validation ── */
    if (argc < 3) {
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }

    if (strcmp(argv[1], "run") != 0) {
        fprintf(stderr, "[ERROR] Unknown command: %s\n", argv[1]);
        print_usage(argv[0]);
        return EXIT_FAILURE;
    }

    /* ── Build child arg bundle ── */
    ChildArgs child_args;
    child_args.argv = &argv[2];   /* e.g. ["/bin/bash", NULL] */
    child_args.argc = argc - 2;

    /* ── Allocate stack for child (clone needs its own stack) ── */
    char *child_stack = malloc(STACK_SIZE);
    if (!child_stack) {
        perror("[ERROR] malloc failed for child stack");
        return EXIT_FAILURE;
    }

    /* Stack grows downward on x86; pass the TOP of the buffer */
    char *stack_top = child_stack + STACK_SIZE;

    // printf("[HOST]  Starting container...\n");
    // printf("[HOST]  Command: %s\n", argv[2]);
    // printf("[HOST]  Rootfs:  %s\n", ROOTFS_PATH);
    // printf("─────────────────────────────────────────\n");

    /*
     * ── clone() — the heart of containers ──
     *
     * Flags used:
     *   CLONE_NEWPID  → new PID namespace  (container sees itself as PID 1)
     *   CLONE_NEWUTS  → new UTS namespace  (container can have its own hostname)
     *   SIGCHLD       → send SIGCHLD to parent when child exits (needed for wait())
     */
    int clone_flags = CLONE_NEWPID | CLONE_NEWUTS | CLONE_NEWNS | SIGCHLD;

    pid_t child_pid = clone(container_main, stack_top, clone_flags, &child_args);
    if (child_pid < 0) {
        perror("[ERROR] clone() failed");
        free(child_stack);
        return EXIT_FAILURE;
    }

    // printf("[HOST]  Container started with host-PID: %d\n", child_pid);

    /* ── Wait for container to finish ── */
    int status;
    if (waitpid(child_pid, &status, 0) < 0) {
        perror("[ERROR] waitpid failed");
        free(child_stack);
        return EXIT_FAILURE;
    }

    // printf("─────────────────────────────────────────\n");
    // if (WIFEXITED(status)) {
    //     printf("[HOST]  Container exited with code: %d\n", WEXITSTATUS(status));
    // } else if (WIFSIGNALED(status)) {
    //     printf("[HOST]  Container killed by signal: %d\n", WTERMSIG(status));
    // }

    free(child_stack);
    
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    return EXIT_FAILURE;
}

/* ═══════════════════════════════════════════════════════
 * container_main()
 * This runs INSIDE the new namespaces (in the child process).
 * Steps: setup hostname → chroot → exec command
 * ═══════════════════════════════════════════════════════ */
static int container_main(void *arg)
{
    ChildArgs *ca = (ChildArgs *)arg;

    // printf("[CONTAINER] PID inside container: %d\n", getpid());

    /* Step 1: Set hostname in our isolated UTS namespace */
    setup_hostname();

    /* Step 2: Change root filesystem to our mini rootfs */
    setup_filesystem();

    /* Step 3: Mount proc inside the new mount/pid namespace so ps works */
    if (mount("proc", "/proc", "proc", 0, NULL) != 0) {
        perror("[CONTAINER ERROR] Failed to mount /proc");
        /* Non-fatal, but ps won't work */
    }

    /* Step 4: Set a basic PATH inside the container */
    setenv("PATH", "/bin:/usr/bin:/sbin", 1);
    setenv("HOME", "/root", 1);
    setenv("TERM", "xterm-256color", 1);

    // printf("[CONTAINER] Executing: %s\n", ca->argv[0]);
    // printf("─────────────────────────────────────────\n\n");

    /* Step 5: Replace this process with the requested command */
    execvp(ca->argv[0], ca->argv);

    /* execvp only returns on error */
    fprintf(stderr, "container: %s: %s\n",
            ca->argv[0], strerror(errno));
    return EXIT_FAILURE;
}

/* ═══════════════════════════════════════════════════════
 * setup_filesystem()
 * Uses chroot() to isolate the container to ./rootfs
 * ═══════════════════════════════════════════════════════ */
static void setup_filesystem(void)
{
    /* chroot() changes what "/" means for this process and its children */
    if (chroot(ROOTFS_PATH) != 0) {
        perror("[CONTAINER ERROR] chroot() failed");
        fprintf(stderr, "  Hint: Did you run 'make setup-rootfs' first?\n");
        fprintf(stderr, "  Hint: Are you running as root (sudo)?\n");
        exit(EXIT_FAILURE);
    }

    /* After chroot, we must also change our working directory to the new "/" */
    if (chdir("/") != 0) {
        perror("[CONTAINER ERROR] chdir('/') after chroot failed");
        exit(EXIT_FAILURE);
    }

    // printf("[CONTAINER] Filesystem isolated to: %s\n", ROOTFS_PATH);
}

/* ═══════════════════════════════════════════════════════
 * setup_hostname()
 * Uses sethostname() inside the new UTS namespace.
 * The host's hostname is NOT affected.
 * ═══════════════════════════════════════════════════════ */
static void setup_hostname(void)
{
    if (sethostname(CONTAINER_HOSTNAME, strlen(CONTAINER_HOSTNAME)) != 0) {
        perror("[CONTAINER ERROR] sethostname() failed");
        exit(EXIT_FAILURE);
    }
    // printf("[CONTAINER] Hostname set to: %s\n", CONTAINER_HOSTNAME);
}

/* ═══════════════════════════════════════════════════════
 * Helpers
 * ═══════════════════════════════════════════════════════ */
static void print_banner(void)
{
    printf("\n");
    printf("  ╔══════════════════════════════════════╗\n");
    printf("  ║   Basic Container (Docker-like)      ║\n");
    printf("  ║   OS Project — B.Tech CSE            ║\n");
    printf("  ╚══════════════════════════════════════╝\n");
    printf("\n");
}

static void print_usage(const char *prog)
{
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  sudo %s run <command> [args...]\n\n", prog);
    fprintf(stderr, "Examples:\n");
    fprintf(stderr, "  sudo %s run /bin/bash\n", prog);
    fprintf(stderr, "  sudo %s run /bin/ls\n", prog);
    fprintf(stderr, "  sudo %s run /bin/echo Hello World\n", prog);
}
// change 1
// new feature
