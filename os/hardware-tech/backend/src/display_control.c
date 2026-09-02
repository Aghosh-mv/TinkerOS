/*
 * TinkerOS Display Control - capability-probing backlight/DPMS backend
 * For oled-shield (wear compensation), adaptive-display, fpga-scaler.
 * Operates real display interfaces:
 *  - backlight via /sys/class/backlight brightness (with max scaling)
 *   - DRM connector status/props via /sys/class/drm
 *   - all reads/writes capability-probed, safe envelope, no crash
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>

static int read_int_file(const char *path, int *out) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    char buf[64]; int n = read(fd, buf, sizeof(buf)-1);
    close(fd);
    if (n <= 0) return -1;
    buf[n]=0; *out = atoi(buf);
    return 0;
}

static int write_str_file(const char *path, const char *val) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) return -1;
    int n = (int)strlen(val);
    int r = (write(fd, val, n) == n) ? 0 : -1;
    close(fd);
    return r;
}

static void print_backlight_info(void) {
    glob_t g;
    if (glob("/sys/class/backlight/*", 0, NULL, &g) == 0) {
        printf("backlights=%zu\n", g.gl_pathc);
        for (size_t i = 0; i < g.gl_pathc; i++) {
            const char *d = g.gl_pathv[i];
            const char *name = strrchr(d, '/') + 1;
            char bm[PATH_MAX], bb[PATH_MAX];
            snprintf(bm, sizeof(bm), "%s/max_brightness", d);
            snprintf(bb, sizeof(bb), "%s/brightness", d);
            int max=255, cur=0;
            read_int_file(bm, &max);
            read_int_file(bb, &cur);
            printf("  bl[%s] current=%d max=%d (%.0f%%)\n", name, cur, max,
                   100.0*cur/(max?max:1));
        }
        globfree(&g);
    } else {
        printf("backlights=0\n");
    }
}

/* Return 0 if a real backlight exists */
static int find_first_backlight(char *out, size_t outsz, int *cur_ptr, int *max_ptr) {
    glob_t g;
    if (glob("/sys/class/backlight/*/brightness", 0, NULL, &g) == 0) {
        for (size_t i = 0; i < g.gl_pathc; i++) {
            snprintf(out, outsz, "%s", g.gl_pathv[i]);
            char mx[PATH_MAX];
            snprintf(mx, sizeof(mx), "%s/max_brightness", g.gl_pathv[i]);
            if (read_int_file(mx, max_ptr) != 0) *max_ptr = 255;
            read_int_file(g.gl_pathv[i], cur_ptr);
            globfree(&g);
            return 0;
        }
        globfree(&g);
    }
    return -1;
}

int main(int argc, char **argv) {
    int dry = 0;
    int argi = 1;
    for (; argi < argc; argi++) {
        if (strcmp(argv[argi], "--dry-run")==0) dry = 1;
        else break;
    }
    if (argi >= argc) {
        fprintf(stderr,
          "TinkerOS display_control v1.0\n"
          "Usage:\n"
          "  display_control probe                 - show backlights/DPMS capability\n"
          "  display_control brightness <0-100>    - set brightness percent (safe)\n"
          "  display_control dim <frac>            - e.g. 0.7 of current (oled wear comp)\n"
          "  display_control read                  - current brightness\n");
        return 2;
    }
    const char *cmd = argv[argi];

    if (strcmp(cmd, "probe") == 0) {
        print_backlight_info();
        glob_t g;
        printf("drm_connectors=");
        if (glob("/sys/class/drm/card*-*", 0, NULL, &g)==0) printf("%zu\n", g.gl_pathc);
        else printf("0\n");
        if (g.gl_pathc) globfree(&g);
        return 0;
    }

    if (strcmp(cmd, "read") == 0 || strcmp(cmd, "brightness") == 0 || strcmp(cmd, "dim") == 0) {
        char path[PATH_MAX]; int cur=0, max=255;
        char dummy[PATH_MAX]; int c2=0;
        if (find_first_backlight(path, sizeof(path), &cur, &max) != 0) {
            printf("brightness=unavailable:no-backlight\n");
            return 1;
        }
        if (strcmp(cmd, "read")==0) {
            printf("brightness=%d\nmax=%d\npct=%.1f\n", cur, max, 100.0*cur/(max?max:1));
            return 0;
        }
        int target = cur;
        if (strcmp(cmd, "brightness")==0) {
            int pct = atoi(argv[argi+1]);
            if (pct < 0) pct = 0; if (pct > 100) pct = 100;
            target = (int)((long long)max * pct / 100);
        } else { /* dim: scale current by fraction, clamp to min 10% */
            double frac = (argi+1 < argc) ? atof(argv[argi+1]) : 0.70;
            double scaled = cur * frac;
            int minok = (int)(max * 0.10);
            target = (int)scaled; if (target < minok) target = minok;
        }
        if (dry) { printf("ok=preview:brightness=%d (was %d)\n", target, cur); return 0; }
        char val[32]; snprintf(val, sizeof(val), "%d", target);
        if (write_str_file(path, val) == 0) {
            printf("ok=backlight:%d/%d (%.0f%%)\n", target, max, 100.0*target/(max?max:1));
            return 0;
        }
        printf("brightness=write-failed:no-permission\n");
        return 1;
    }

    fprintf(stderr, "unknown command\n");
    return 2;
}
