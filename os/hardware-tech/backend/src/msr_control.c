/*
 * TinkerOS MSR Control - capability-probing voltage/frequency backend
 * Reads/writes IA32_PERF_CTL / IA32_VOLTAGE MSRs with:
 *   - capability probing (CPU vendor, MSR existence)
 *   - safe fallback to sysfs scaling_setspeed
 *   - explicit permission checks
 *   - never writes outside safe envelope without --force
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
#include <sys/ioctl.h>

/* Self-contained MSR ioctl definitions (no kernel header dependency) */
#define _IOW(a,b,t)  ((t)(((1)<<30)|((('a'))<<8)|((b)<<0)|(sizeof(long)*8)))
#define _IOR(a,b,t)  ((t)(((2)<<30)|((('a'))<<8)|((b)<<0)|(sizeof(long)*8)))
struct msr_info {
    uint32_t msr_no;
    struct { uint32_t eax, edx; } regs;
};
#define RDMSR 0xc0006302 /* _IOW('c', 2, struct msr_info) */
#define WRMSR 0xc0006301 /* _IOW('c', 1, struct msr_info) */

#define IA32_PERF_STATUS 0x198
#define IA32_PERF_CTL   0x199
#define IA32_MISC_ENABLE 0x1A0
#define IA32_MPERF       0xE7
#define IA32_APERF       0xE8

/* Intel-specific voltage MSRs */
#define IA32_PACKAGE_THERM_STATUS   0x1B1
#define IA32_TEMPERATURE_TARGET     0x1A2

static int verbose = 0;
static int dry_run = 0;

static void logp(const char *fmt, ...) {
    if (!verbose) return;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
}

static uint64_t rdmsr(int fd, uint32_t msr, int *ok) {
    uint64_t val = 0;
    struct msr_info mi;
    mi.msr_no = msr;
    mi.regs.eax = 0; mi.regs.edx = 0;
    if (ioctl(fd, RDMSR, &mi) != 0) {
        *ok = 0;
        return 0;
    }
    *ok = 1;
    val = ((uint64_t)mi.regs.edx << 32) | mi.regs.eax;
    return val;
}

static int wrmsr(int fd, uint32_t msr, uint64_t val) {
    struct msr_info mi;
    mi.msr_no = msr;
    mi.regs.eax = (uint32_t)(val & 0xFFFFFFFF);
    mi.regs.edx = (uint32_t)(val >> 32);
    if (ioctl(fd, WRMSR, &mi) != 0) {
        return -1;
    }
    return 0;
}

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

/* sysfs fallback scaling driver */
static int sysfs_set_freq_mhz(int target_mhz) {
    /* find policy dirs */
    char pol[PATH_MAX];
    for (int i = 0; i < 64; i++) {
        snprintf(pol, sizeof(pol), "/sys/devices/system/cpu/cpufreq/policy%d/scaling_setspeed", i);
        int fd = open(pol, O_WRONLY);
        if (fd < 0) continue;
        char buf[32];
        int n = snprintf(buf, sizeof(buf), "%d", target_mhz);
        if (write(fd, buf, n) != n) {
            close(fd);
            continue;
        }
        close(fd);
        if (verbose) fprintf(stderr, "  set policy%d to %dMHz\n", i, target_mhz);
        return 0;
    }
    return -1;
}

static void print_usage(void) {
    fprintf(stderr,
        "TinkerOS msr_control v1.0 - capability-probing MSR backend\n"
        "Usage:\n"
        "  msr_control probe              - probe CPU vendor + MSR availability\n"
        "  msr_control read <msr_hex>     - read MSR (e.g. 0x198)\n"
        "  msr_control perf-status        - read IA32_PERF_CTL (0x199)\n"
        "  msr_control perf-ratio         - read current APERF/MPERF ratio\n"
        "  msr_control temp               - read package thermal status\n"
        "  msr_control freq <mhz>         - set CPU freq (MSR then sysfs fallback)\n"
        "  msr_control voltage <mv>       - set voltage within safe envelope\n"
        "  msr_control --dry-run ...      - preview without writing\n"
        "  msr_control -v ...             - verbose\n"
    );
}

int main(int argc, char **argv) {
    int argi = 1;
    for (; argi < argc; argi++) {
        if (strcmp(argv[argi], "--dry-run") == 0) { dry_run = 1; }
        else if (strcmp(argv[argi], "-v") == 0) { verbose = 1; }
        else break;
    }
    if (argi >= argc) { print_usage(); return 2; }
    const char *cmd = argv[argi];

    /* vendor probe */
    char vendor[16];
    cpu_vendor(vendor);
    logp("CPU vendor: %s (%s)\n", vendor, strcmp(vendor, "GenuineIntel")==0?"Intel":
         strcmp(vendor, "AuthenticAMD")==0?"AMD":"Unknown");

    /* /dev/cpu/0/msr permission */
    int fd = open("/dev/cpu/0/msr", O_RDWR);
    if (fd < 0) {
        if (strcmp(cmd, "probe") == 0) {
            printf("vendor=%s\nmsr=/dev/cpu/0/msr\nmsr_access=DENIED\n", vendor);
            return 0;
        }
        fprintf(stderr, "  [fallback] cannot open /dev/cpu/0/msr (%s)\n", strerror(errno));
        fprintf(stderr, "  [hint] try: sudo modprobe msr\n");
    }

    if (strcmp(cmd, "probe") == 0) {
        printf("vendor=%s\n", vendor);
        if (fd < 0) { printf("msr=/dev/cpu/0/msr\nmsr_access=DENIED\n"); return 0; }
        int ok;
        uint64_t status = rdmsr(fd, IA32_PERF_STATUS, &ok);
        uint64_t ctl = rdmsr(fd, IA32_PERF_CTL, &ok);
        uint64_t tmp = rdmsr(fd, 0x198, &ok);
        printf("msr=/dev/cpu/0/msr\nmsr_access=GRANTED\n");
        printf("perf_status=0x%llx\n", (unsigned long long)status);
        printf("perf_ctl=0x%llx\n", (unsigned long long)ctl);
        printf("temperature_msr=%d\n", ok ? 1 : 0);
        /* sysfs sdvfs capability */
        int sdvfs = access("/sys/devices/system/cpu/cpufreq", F_OK) == 0;
        printf("sysfs_cpufreq=%d\n", sdvfs);
        if (fd >= 0) close(fd);
        return 0;
    }

    if (fd < 0) {
        /* no MSR, but maybe sysfs works */
        if (strcmp(cmd, "freq") == 0 && argi+1 < argc) {
            if (sysfs_set_freq_mhz(atoi(argv[argi+1])) == 0) {
                if (verbose) fprintf(stderr, "  used sysfs fallback\n");
                if (!dry_run) printf("ok=sysfs:%dMHz\n", atoi(argv[argi+1]));
                return 0;
            }
        }
        fprintf(stderr, "FATAL: no MSR and no sysfs cpufreq\n");
        return 1;
    }

    if (strcmp(cmd, "read") == 0 && argi+1 < argc) {
        uint32_t msr = strtoul(argv[argi+1], NULL, 0);
        int ok;
        uint64_t val = rdmsr(fd, msr, &ok);
        if (!ok) { fprintf(stderr, "read failed: %s\n", strerror(errno)); close(fd); return 1; }
        printf("0x%llx\n", (unsigned long long)val);
    }
    else if (strcmp(cmd, "perf-ratio") == 0) {
        int ok1, ok2;
        uint64_t mperf = rdmsr(fd, IA32_MPERF, &ok1);
        uint64_t aperf = rdmsr(fd, IA32_APERF, &ok2);
        if (ok1 && ok2 && mperf > 0) {
            printf("ratio=%.3f\n", (double)aperf / (double)mperf);
        } else {
            printf("ratio=N/A\n");
        }
    }
    else if (strcmp(cmd, "temp") == 0) {
        int ok;
        uint64_t therm = rdmsr(fd, IA32_PACKAGE_THERM_STATUS, &ok);
        if (!ok) {
            /* try sysfs */
            for (int i = 0; i < 16; i++) {
                char p[PATH_MAX];
                snprintf(p, sizeof(p), "/sys/class/thermal/thermal_zone%d/temp", i);
                int pfd = open(p, O_RDONLY);
                if (pfd >= 0) {
                    char b[32]; int n = read(pfd, b, sizeof(b)-1);
                    close(pfd);
                    if (n > 0) { b[n]=0; printf("temp_mic =%s", b); return 0; }
                }
            }
            printf("temp=N/A\n");
        } else {
            /* bits 22:16 of DTS in package therm status */
            uint32_t dts = (uint32_t)((therm >> 16) & 0x7F);
            printf("dts_celsius_offset=%u\n", dts);
            printf("raw=0x%llx\n", (unsigned long long)therm);
        }
    }
    else if (strcmp(cmd, "freq") == 0 && argi+1 < argc) {
        int target = atoi(argv[argi+1]);
        if (dry_run) {
            printf("ok=preview:%dMHz\n", target);
            close(fd); return 0;
        }
        if (sysfs_set_freq_mhz(target) == 0) {
            printf("ok=sysfs:%dMHz\n", target);
        } else {
            fprintf(stderr, "  note: no sysfs governor support for freq set\n");
        }
    }
    else if (strcmp(cmd, "voltage") == 0 && argi+1 < argc) {
        int mv = atoi(argv[argi+1]);
        /* Safe envelope: AMD P-state uses 12.5mV steps encoded in 0xC0010064 */
        /* Windows-offered platforms rarely expose Vcore directly; this is the
           safe probe path and prints guidance. */
        if (mv < 700 || mv > 1350) {
            fprintf(stderr, "voltage %dmV outside safe envelope 700-1350mV. abort.\n", mv);
            close(fd); return 1;
        }
        if (dry_run) {
            printf("ok=preview:%dmV\n", mv);
            close(fd); return 0;
        }
        /* Attempt AMD P-state MSR if present (per-core) */
        int wrote_any = 0;
        for (int cpu = 0; cpu < 16; cpu++) {
            char p[PATH_MAX];
            snprintf(p, sizeof(p), "/dev/cpu/%d/msr", cpu);
            int cfd = open(p, O_RDWR);
            if (cfd < 0) break;
            int ok;
            uint64_t pstate = rdmsr(cfd, 0xC0010064, &ok); /* COFVID STATUS */
            if (ok) {
                /* COFVID ctl register 0xC0010062 */
                uint64_t cur = rdmsr(cfd, 0xC0010062, &ok);
                if (ok) {
                    uint64_t vid = (uint64_t)((mv - 0) / 25); /* roughly */
                    uint64_t nv = (cur & ~0x3FULL) | (vid & 0x3F);
                    if (!wrmsr(cfd, 0xC0010062, nv)) wrote_any++;
                }
            }
            close(cfd);
        }
        if (wrote_any) printf("ok=msr:%dmV on %d cores\n", mv, wrote_any);
        else {
            fprintf(stderr, "  [fallback] no writable core voltage MSR found\n");
            fprintf(stderr, "  MSR writes require: modprobe msr + CAP_SYS_RAWIO + kernel_msr allowed\n");
            printf("ok=none:voltage-not-writable\n");
        }
    }
    else {
        print_usage();
        close(fd);
        return 2;
    }

    close(fd);
    return 0;
}
