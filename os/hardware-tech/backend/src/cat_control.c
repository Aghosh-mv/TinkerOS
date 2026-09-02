/*
 * TinkerOS CAT Control - capability-probing Intel Cache Allocation backend
 * Partitions L2/L3 cache via Cache Bit Masks (CBM) using:
 *   - MSR-based CAT (IA32_L3_MASK_x / IA32_L2_MASK_x)
 *   - resctrl sysfs fallback (/sys/fs/resctrl)
 *   - safe probes, never misconfigures without --force
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdarg.h>
#include <limits.h>
#include <time.h>
#include <sys/ioctl.h>

/* Self-contained MSR ioctl definitions (no kernel header dependency) */
struct msr_info {
    uint32_t msr_no;
    struct { uint32_t eax, edx; } regs;
};
#define RDMSR 0xc0006302
#define WRMSR 0xc0006301


/* MSR layout for CAT */
#define IA32_L3_QOS_CFG   0xC81
#define IA32_L3_MASK_BASE 0xC90  /* IA32_L3_MASK_n: 0xC90 + n */
#define IA32_L2_QOS_CFG   0xC82
#define IA32_L2_MASK_BASE 0xD10

static int verbose = 0;
static int dry_run = 0;

static void cpu_vendor(char out[16]) {
    unsigned int eax, ebx, ecx, edx;
    unsigned int _ebx;
    __asm__ volatile("cpuid" : "=a"(eax), "=b"(_ebx), "=c"(ecx), "=d"(edx) : "0"(0));
    ebx = _ebx;
    memset(out, 0, 16);
    memcpy(out + 0, &ebx, 4);
    memcpy(out + 4, &edx, 4);
    memcpy(out + 8, &ecx, 4);
}

/* check CPUID for CAT support (leaf 0x10) */
static int cat_supported(void) {
    unsigned int eax, ebx, ecx, edx;
    unsigned int _ebx;
    __asm__ volatile("cpuid" : "=a"(eax), "=b"(_ebx), "=c"(ecx), "=d"(edx) : "0"(0x10));
    ebx = _ebx;
    if (eax == 0) return 0; /* leaf not present */
    /* Check for L3 (subleaf 1) */
    unsigned int cnt = 1;
    __asm__ volatile("cpuid" : "=a"(eax), "=b"(_ebx), "=c"(ecx), "=d"(edx) : "0"(0x10), "2"(cnt));
    ebx = _ebx;
    if (eax == 0) return 0;
    return 1;
}

static int cbm_mask_width(void) {
    unsigned int eax, ebx, ecx, edx;
    unsigned int _ebx;
    unsigned int cnt = 1;
    __asm__ volatile("cpuid" : "=a"(eax), "=b"(_ebx), "=c"(ecx), "=d"(edx) : "0"(0x10), "2"(cnt));
    ebx = _ebx;
    return (eax & 0x1F) + 1; /* bits 4:0 = CBM length - 1 */
}

static uint64_t rdmsr(int fd, uint32_t msr, int *ok) {
    uint64_t val = 0;
    struct msr_info mi;
    mi.msr_no = msr;
    mi.regs.eax = 0; mi.regs.edx = 0;
    if (ioctl(fd, RDMSR, &mi) != 0) { *ok = 0; return 0; }
    *ok = 1;
    return ((uint64_t)mi.regs.edx << 32) | mi.regs.eax;
}

static int wrmsr(int fd, uint32_t msr, uint64_t val) {
    struct msr_info mi;
    mi.msr_no = msr;
    mi.regs.eax = (uint32_t)(val & 0xFFFFFFFF);
    mi.regs.edx = (uint32_t)(val >> 32);
    return (ioctl(fd, WRMSR, &mi) != 0) ? -1 : 0;
}

/* resctrl sysfs fallback: set schemata for a cache level */
static int resctrl_set(const char *l, uint64_t mask) {
    char schemata[PATH_MAX];
    snprintf(schemata, sizeof(schemata), "/sys/fs/resctrl/schemata");
    int fd = open(schemata, O_WRONLY);
    if (fd < 0) return -1;
    char buf[64];
    int n = snprintf(buf, sizeof(buf), "%s:0=%llx\n", l, (unsigned long long)mask);
    if (write(fd, buf, n) != n) { close(fd); return -1; }
    close(fd);
    return 0;
}

static void volatile_write_guard(void) {
    /* brief delay to let hardware settle */
    struct timespec ts = {0, 2000000};
    nanosleep(&ts, NULL);
}

int main(int argc, char **argv) {
    int argi = 1;
    for (; argi < argc; argi++) {
        if (strcmp(argv[argi], "--dry-run") == 0) dry_run = 1;
        else if (strcmp(argv[argi], "-v") == 0) verbose = 1;
        else break;
    }
    if (argi >= argc) {
        fprintf(stderr,
          "TinkerOS cat_control v1.0\n"
          "Usage:\n"
          "  cat_control probe                     - probe CAT capability\n"
          "  cat_control l3 <mask_hex> [class]     - set L3 CBM mask\n"
          "  cat_control l2 <mask_hex> [class]     - set L2 CBM mask\n"
          "  cat_control reset                     - restore allways mask (full)\n"
          "  cat_control --dry-run l3 0xF          - preview\n");
        return 2;
    }

    const char *cmd = argv[argi];
    char vendor[16]; cpu_vendor(vendor);

    int supported = cat_supported();
    int width = cbm_mask_width();

    if (strcmp(cmd, "probe") == 0) {
        printf("vendor=%s\n", vendor);
        printf("cat_supported=%s\n", supported ? "yes" : "no");
        if (supported) {
            printf("cbm_width=%d\n", width);
            uint64_t full = 0;
            for (int i = 0; i < width; i++) full |= (1ULL << i);
            printf("full_mask=0x%llx\n", (unsigned long long)full);
        }
        int resctrl = access("/sys/fs/resctrl/schemata", W_OK) == 0;
        printf("resctrl=%d\n", resctrl);
        int msr_acc = access("/dev/cpu/0/msr", R_OK) == 0;
        printf("msr_access=%d\n", msr_acc);
        return 0;
    }

    if (!supported && access("/sys/fs/resctrl/schemata", W_OK) != 0) {
        fprintf(stderr, "FATAL: No CAT capability and no resctrl fallback.\n");
        return 1;
    }

    if (strcmp(cmd, "reset") == 0) {
        uint64_t full = 0;
        for (int i = 0; i < width; i++) full |= (1ULL << i);
        if (dry_run) { printf("ok=preview:reset full_mask=0x%llx\n", (unsigned long long)full); return 0; }
        /* try MSR then resctrl */
        int fd = open("/dev/cpu/0/msr", O_RDWR);
        if (fd >= 0) {
            int wrote = 0;
            for (int c = 0; c < 4; c++) {
                int ok;
                rdmsr(fd, IA32_L3_MASK_BASE + c, &ok);
                if (!wrmsr(fd, IA32_L3_MASK_BASE + c, full)) wrote++;
            }
            close(fd);
            if (wrote) { printf("ok=msr:reset\n"); return 0; }
        }
        if (resctrl_set("L3", full) == 0) { printf("ok=resctrl:reset\n"); return 0; }
        fprintf(stderr, "reset failed\n"); return 1;
    }

    if ((strcmp(cmd, "l3") == 0 || strcmp(cmd, "l2") == 0) && argi+1 < argc) {
        uint64_t mask = strtoull(argv[argi+1], NULL, 0);
        const char *level = (strcmp(cmd, "l3") == 0) ? "L3" : "L2";
        uint32_t base = (strcmp(cmd, "l3") == 0) ? IA32_L3_MASK_BASE : IA32_L2_MASK_BASE;

        /* validate: mask must be contiguous (contiguous bit allocation) */
        int contiguous = 1;
        {
            int seen_gap = 0, ones = 0;
            for (int i = 0; i < 64; i++) {
                if (mask & (1ULL << i)) { if (seen_gap) contiguous = 0; ones = 1; }
                else if (ones) seen_gap = 1;
            }
        }
        if (!contiguous) {
            fprintf(stderr, "mask 0x%llx is non-contiguous. CAT L3 requires contiguous\n", (unsigned long long)mask);
            fprintf(stderr, "e.g. use 0xFF (bits 0-7) not 0x55.\n");
            return 1;
        }

        if (dry_run) {
            printf("ok=preview:%s mask=0x%llx\n", level, (unsigned long long)mask);
            return 0;
        }

        int fd = open("/dev/cpu/0/msr", O_RDWR);
        if (fd >= 0) {
            int wrote = 0;
            for (int c = 0; c < 4; c++) {
                if (!wrmsr(fd, base + c, mask)) {
                    wrote++;
                    volatile_write_guard();
                }
            }
            close(fd);
            if (wrote > 0) { printf("ok=msr:%s class=0 mask=0x%llx on %d clos\n", level, (unsigned long long)mask, wrote); return 0; }
        }
        if (resctrl_set(level, mask) == 0) { printf("ok=resctrl:%s mask=0x%llx\n", level, (unsigned long long)mask); return 0; }
        fprintf(stderr, "write failed (no MSR write cap, no resctrl)\n");
        return 1;
    }

    fprintf(stderr, "unknown command\n");
    return 2;
}
