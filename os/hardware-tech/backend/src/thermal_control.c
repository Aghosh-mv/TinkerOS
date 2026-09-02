/*
 * TinkerOS Thermal Control - capability-probing thermal backend
 * Aggregates package/core temps from multiple sources:
 *   - IA32_THERM_STATUS MSR per-core (fast, 1000x/s capable)
 *   - hwmon /sys/class/thermal zones (fallback)
 *   - generates a heat map across cores
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>

/* Self-contained MSR ioctl definitions (no kernel header dependency) */
struct msr_info {
    uint32_t msr_no;
    struct { uint32_t eax, edx; } regs;
};
#define RDMSR 0xc0006302
#define WRMSR 0xc0006301

#include <sched.h>

#define IA32_THERM_STATUS  0x19C
#define IA32_PACKAGE_STATUS 0x1B1
#define IA32_TEMP_TARGET   0x1A2

static int ncpu(void) {
    return sysconf(_SC_NPROCESSORS_CONF);
}

/* returns thermal offset (DTS) reading for a cpu; -1 on error */
static int core_temp(int cpu, long *tjj) {
    char path[64];
    snprintf(path, sizeof(path), "/dev/cpu/%d/msr", cpu);
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    int ok;
    struct msr_info mi;
    mi.msr_no = IA32_TEMP_TARGET;
    mi.regs.eax = 0; mi.regs.edx = 0;
    if (ioctl(fd, RDMSR, &mi) != 0) { close(fd); return -1; }
    /* temp target bits 23:16 = TjMax */
    *tjj = (mi.regs.eax >> 16) & 0xFF;
    mi.msr_no = IA32_THERM_STATUS;
    mi.regs.eax = 0; mi.regs.edx = 0;
    if (ioctl(fd, RDMSR, &mi) != 0) { close(fd); return -1; }
    long dts = (mi.regs.eax >> 16) & 0x7F; /* digital thermal sensor offset */
    close(fd);
    if (dts == 0) return -1; /* no readout */
    return (int)dts;
}

int main(int argc, char **argv) {
    int raw = 0, continuous = 0, interval_us = 1000;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--raw")==0) raw = 1;
        else if (strcmp(argv[i], "--continuous")==0) continuous = 1;
        else if (strcmp(argv[i], "--interval")==0 && i+1<argc) interval_us = atoi(argv[++i]);
    }
    int nc = ncpu();

    /* Try MSR path first */
    int got_msr = 0;
    long tjj = 100;
    for (int i = 0; i < nc; i++) {
        int r = core_temp(i, &tjj);
        if (r > 0) { got_msr = 1; break; }
    }

    if (!got_msr) {
        /* sysfs fallback: gather thermal zones */
        if (raw) {
            for (int z = 0; z < 32; z++) {
                char p[128];
                snprintf(p, sizeof(p), "/sys/class/thermal/thermal_zone%d/temp", z);
                int fd = open(p, O_RDONLY);
                if (fd < 0) break;
                char b[64]; int n = read(fd, b, sizeof(b)-1);
                close(fd);
                if (n > 0) { b[n]=0; printf("zone%d=%smC\n", z, b); }
            }
            return 0;
        }
        /* human summary from zones */
        int max = -1000000, ndx = -1, count = 0;
        for (int z = 0; z < 32; z++) {
            char p[128];
            snprintf(p, sizeof(p), "/sys/class/thermal/thermal_zone%d/temp", z);
            int fd = open(p, O_RDONLY);
            if (fd < 0) break;
            char b[64]; int n = read(fd, b, sizeof(b)-1);
            close(fd);
            if (n > 0) { b[n]=0; int v = atoi(b); count++;
                if (v > max) { max = v; ndx = z; } }
        }
        if (count == 0) { printf("mean_c=N/A\nmax_c=N/A\nsource=none\n"); return 1; }
        printf("mean_c=%.1f\nmax_c=%.1f\nmax_zone=%d\nsource=sysfs:hwmon\n",
               (double)max/1000.0, (double)max/1000.0, ndx);
        return 0;
    }

    if (continuous) {
        while (1) {
            double sum = 0; int nvalid = 0; long curTj = tjj;
            int maxc = -1; double maxT = -1;
            for (int i = 0; i < nc; i++) {
                int d = core_temp(i, &curTj);
                if (d < 0) continue;
                double c = curTj - d;
                sum += c; nvalid++;
                if (c > maxT) { maxT = c; maxc = i; }
            }
            if (nvalid > 0) {
                if (raw) printf("mean=%.1f max=%.1f max_core=%d n=%d\n",
                                sum/nvalid, maxT, maxc, nvalid);
            }
            usleep(interval_us);
        }
    }

    /* one-shot heat map */
    long curTj = tjj;
    double sum = 0; int nvalid = 0, maxc = -1; double maxT = -1;
    for (int i = 0; i < nc; i++) {
        int d = core_temp(i, &curTj);
        if (d < 0) continue;
        double c = curTj - d;
        sum += c; nvalid++;
        if (c > maxT) { maxT = c; maxc = i; }
    }
    if (nvalid == 0) { printf("mean_c=N/A\n"); return 1; }
    double mean = sum / nvalid;
    printf("mean_c=%.1f\nmax_c=%.1f\nmax_core=%d\ncores=%d\nsource=msr\n",
           mean, maxT, maxc, nvalid);
    printf("heatmap=");
    for (int i = 0; i < nc; i++) {
        int d = core_temp(i, &curTj);
        printf("%s%c", i==0?"":",", (d<0)?'-':(curTj-d > mean+4?'H':(curTj-d < mean-4?'L':'M')));
    }
    printf("\n");
    return 0;
}
