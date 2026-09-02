/*
 * TinkerOS Battery Control - capability-probing charge/health backend
 * For lifespan-doubler (micro-current trickle charging).
 * Operates real battery interfaces:
 *   - read status/level/voltage/current/temp/health from /sys/class/power_supply
 *   - set charge thresholds (charge_control_end_threshold, charge_control_limit,
 *     input_current_limit) to enable trickle/lifespan-limited charging
 *   - capability-probed: only writes what the kernel exposes; safe envelope
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>

static char g_bat[PATH_MAX] = "";

static int find_battery(void) {
    glob_t g;
    if (glob("/sys/class/power_supply/BAT*", 0, NULL, &g) == 0) {
        for (size_t i = 0; i < g.gl_pathc; i++) {
            const char *d = g.gl_pathv[i];
            char type[PATH_MAX];
            snprintf(type, sizeof(type), "%s/type", d);
            int fd = open(type, O_RDONLY);
            if (fd >= 0) {
                char b[32]; int n = read(fd, b, sizeof(b)-1);
                close(fd);
                if (n>0) { b[n]=0; if (strstr(b, "Battery")) {
                    snprintf(g_bat, sizeof(g_bat), "%s", d);
                    globfree(&g); return 0; } }
            }
        }
        globfree(&g);
    }
    return -1;
}

static const char *attr_path(char *out, size_t n, const char *attr) {
    snprintf(out, n, "%s/%s", g_bat, attr);
    return out;
}

static int read_attr(const char *attr, char *out, size_t n) {
    char p[PATH_MAX];
    attr_path(p, sizeof(p), attr);
    int fd = open(p, O_RDONLY);
    if (fd < 0) return -1;
    int r = read(fd, out, n-1);
    close(fd);
    if (r <= 0) return -1;
    out[r]=0;
    size_t L = strlen(out); if (L && out[L-1]=='\n') out[L-1]=0;
    return 0;
}

static int write_attr(const char *attr, const char *val) {
    char p[PATH_MAX];
    attr_path(p, sizeof(p), attr);
    int fd = open(p, O_WRONLY);
    if (fd < 0) return -1;
    int n = (int)strlen(val);
    int r = (write(fd, val, n) == n) ? 0 : -1;
    close(fd);
    return r;
}

static void print_status(void) {
    char v[64], cap[64];
    printf("battery=%s\n", g_bat);
    if (read_attr("status", v, sizeof(v))==0) printf("status=%s\n", v);
    if (read_attr("capacity", v, sizeof(v))==0) printf("capacity=%s%%\n", v);
    if (read_attr("energy_now", v, sizeof(v))==0) printf("energy_now_uw=%s\n", v);
    if (read_attr("energy_full", v, sizeof(v))==0) printf("energy_full_uw=%s\n", v);
    if (read_attr("energy_full_design", cap, sizeof(cap))==0) printf("design_uw=%s\n", cap);
    if (read_attr("voltage_now", v, sizeof(v))==0) printf("voltage_now_uv=%s\n", v);
    if (read_attr("current_now", v, sizeof(v))==0) printf("current_now_ua=%s\n", v);
    if (read_attr("temp", v, sizeof(v))==0) printf("temp_tenth_c=%s\n", v);
    if (read_attr("energy_full", v, sizeof(v))==0 && read_attr("energy_full_design", cap, sizeof(cap))==0) {
        long long a=atoll(v), b=atoll(cap);
        if (b>0) printf("health_pct=%.1f\n", 100.0*(double)a/b);
    }
    char p[PATH_MAX];
    attr_path(p, sizeof(p), "charge_control_end_threshold");
    printf("charge_limit_supported=%s\n", access(p, F_OK)==0 ? "yes":"no");
}

int main(int argc, char **argv) {
    int dry = 0, argi = 1;
    for (; argi < argc; argi++) {
        if (strcmp(argv[argi], "--dry-run")==0) dry = 1;
        else break;
    }
    if (argi >= argc) {
        fprintf(stderr,
          "TinkerOS battery_control v1.0\n"
          "Usage:\n"
          "  battery_control probe                 - read status + limit support\n"
          "  battery_control charge-limit <0-100>  - set charge stop threshold %\n"
          "  battery_control current <ma>          - set charge current (ma)\n"
          "  battery_control status                - same as probe\n");
        return 2;
    }
    if (find_battery() != 0) { printf("battery=none\n"); return 1; }
    const char *cmd = argv[argi];

    if (strcmp(cmd, "probe")==0 || strcmp(cmd, "status")==0) { print_status(); return 0; }

    if (strcmp(cmd, "charge-limit")==0 && argi+1<argc) {
        int pct = atoi(argv[argi+1]);
        if (pct < 20 || pct > 100) {
            fprintf(stderr, "charge limit %d%% outside safe 20-100%% envelope\n", pct);
            return 1;
        }
        char p[PATH_MAX];
        attr_path(p, sizeof(p), "charge_control_end_threshold");
        if (access(p, F_OK)!=0) {
            printf("charge-limit=unsupported:no-attribute\n");
            return 1;
        }
        char val[16]; snprintf(val, sizeof(val), "%d", pct);
        if (dry) { printf("ok=preview:charge-limit=%d%%\n", pct); return 0; }
        if (write_attr("charge_control_end_threshold", val)==0) {
            printf("ok=charge-limit:%d%%\n", pct); return 0;
        }
        printf("charge-limit=write-failed:no-permission\n"); return 1;
    }

    if (strcmp(cmd, "current")==0 && argi+1<argc) {
        int ma = atoi(argv[argi+1]);
        if (ma < 100 || ma > 5000) {
            fprintf(stderr, "current %dmA outside safe 100-5000mA envelope\n", ma);
            return 1;
        }
        /* try input_current_limit (uA) */
        char p[PATH_MAX]; int wrote = 0;
        attr_path(p, sizeof(p), "input_current_limit");
        if (access(p, F_OK)==0 && !dry) {
            char val[32]; snprintf(val, sizeof(val), "%d", ma*1000);
            if (write_attr("input_current_limit", val)==0) { printf("ok=input-current-limit:%dmA\n", ma); wrote=1; }
        }
        if (!wrote) {
            /* fall back to charge_control_limit (uA) */
            attr_path(p, sizeof(p), "charge_control_limit");
            if (access(p, F_OK)==0) {
                if (dry) { printf("ok=preview:charge-control-limit:%dmA\n", ma); }
                else { char val[32]; snprintf(val, sizeof(val), "%d", ma*1000);
                    if (write_attr("charge_control_limit", val)==0) printf("ok=charge-control-limit:%dmA\n", ma);
                    else printf("current=write-failed:no-permission\n"); }
                return 0;
            }
            printf("current=unsupported:no-limit-attribute\n");
            return 1;
        }
        return 0;
    }

    fprintf(stderr, "unknown command\n");
    return 2;
}
