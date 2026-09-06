/*
 * TinkerOS Fan Control - capability-probing PWM/tach backend
 * Drives fan speed via:
 *   - hwmon sysfs pwmX (with manual/auto enable)
 *   - ThinkPad ACPI (/proc/acpi/ibm/fan) fallback
 *   - safe ramped changes + tachometer readback
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>

static int write_file(const char *path, const char *val) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) return -1;
    int n = (int)strlen(val);
    int r = (write(fd, val, n) == n) ? 0 : -1;
    close(fd);
    return r;
}

static int read_int(const char *path, int *out) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    char buf[64];
    int n = read(fd, buf, sizeof(buf)-1);
    close(fd);
    if (n <= 0) return -1;
    buf[n]=0;
    *out = atoi(buf);
    return 0;
}

static void find_pwms(char pwms[][64], int *npwm) {
    glob_t g;
    *npwm = 0;
    for (int h = 0; h < 64; h++) {
        char hw[128];
        snprintf(hw, sizeof(hw), "/sys/class/hwmon/hwmon%d/pwm*", h);
        if (glob(hw, 0, NULL, &g) == 0) {
            for (size_t i = 0; i < g.gl_pathc && *npwm < 32; i++) {
                const char *p = g.gl_pathv[i];
                if (strstr(p, "_enable") || strstr(p, "_max") || strstr(p, "_freq")) continue;
                snprintf(pwms[(*npwm)++], 64, "%s", p);
            }
            globfree(&g);
        }
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,
          "TinkerOS fan_control v1.0\n"
          "Usage:\n"
          "  fan_control probe                      - list fans/capabilities\n"
          "  fan_control set <pct>                  - set speed 0-100 (manual)\n"
          "  fan_control ramped <pct> <step_s>      - smooth ramp to pct\n"
          "  fan_control pulse <hz> <dur_ms>        - oscillate (for dust dislodger)\n"
          "  fan_control read                       - read tachometers\n"
          "  fan_control auto                       - restore automatic\n");
        return 2;
    }
    const char *cmd = argv[1];
    char pwms[32][64]; int npwm = 0;

    if (strcmp(cmd, "probe") == 0) {
        find_pwms(pwms, &npwm);
        printf("pwm_count=%d\n", npwm);
        for (int i = 0; i < npwm; i++) {
            printf("pwm%d=%s\n", i, pwms[i]);
            int max = 255, cur = 0;
            char mx[128]; snprintf(mx, sizeof(mx), "%s_max", pwms[i]);
            if (read_int(mx, &max)) max = 255;
            if (read_int(pwms[i], &cur)) cur = 0;
            printf("  max=%d current=%d (%.0f%%)\n", max, cur, 100.0*cur/max);
        }
        int tp = access("/proc/acpi/ibm/fan", W_OK)==0;
        printf("thinkpad=%d\n", tp);
        return 0;
    }

    if (strcmp(cmd, "read") == 0) {
        find_pwms(pwms, &npwm);
        int any = 0;
        for (int i = 0; i < npwm; i++) {
            char fan[128];
            /* derive fanN_input from pwmN */
            char *base = strrchr(pwms[i], '/');
            if (!base) continue;
            int id = atoi(base+3);
            snprintf(fan, sizeof(fan), "/sys/class/hwmon/hwmon*/fan%d_input", id);
            glob_t g;
            if (glob(fan, 0, NULL, &g)==0) {
                for (size_t k=0;k<g.gl_pathc;k++) {
                    int v; if (!read_int(g.gl_pathv[k], &v) && v>0) {
                        printf("fan%d_rpm=%d\n", id, v); any=1;
                    }
                }
                globfree(&g);
            }
        }
        if (!any) printf("tach=none\n");
        return 0;
    }

    if (strcmp(cmd, "set") == 0 && argc >= 3) {
        int pct = atoi(argv[2]);
        if (pct < 0) pct = 0;
        if (pct > 100) pct = 100;
        find_pwms(pwms, &npwm);
        if (npwm == 0) {
            /* thinkpad fallback */
            char buf[32];
            snprintf(buf, sizeof(buf), "level %d", pct<50?2:7);
            if (write_file("/proc/acpi/ibm/fan", buf)==0) {
                printf("ok=thinkpad:%d%%\n", pct); return 0;
            }
            fprintf(stderr, "no PWM controllers\n"); return 1;
        }
        int wrote = 0;
        for (int i = 0; i < npwm; i++) {
            int max = 255;
            char mx[128]; snprintf(mx, sizeof(mx), "%s_max", pwms[i]);
            read_int(mx, &max);
            int target = (int)((long long)max * pct / 100);
            char en[128]; snprintf(en, sizeof(en), "%s_enable", pwms[i]);
            /* set manual (1) */
            write_file(en, "1");
            char val[32]; snprintf(val, sizeof(val), "%d", target);
            if (write_file(pwms[i], val)==0) wrote++;
        }
        printf("ok=pwm:%d%% on %d fans\n", pct, wrote);
        return 0;
    }

    if (strcmp(cmd, "ramped") == 0 && argc >= 4) {
        int target = atoi(argv[2]);
        int step_us = atoi(argv[3]) * 1000;
        find_pwms(pwms, &npwm);
        /* read current avg pct, then ramp */
        int cur_max = 0;
        for (int i=0;i<npwm;i++) { char mx[128]; snprintf(mx,sizeof(mx),"%s_max",pwms[i]); int m=255; read_int(mx,&m); if(m>cur_max)cur_max=m; }
        int cur = cur_max; /* start from max to be safe */
        int from = cur_max * 100.0 / (cur_max?cur_max:255);
        if (from > 100) from = 100;
        /* rapid ramp in 5% steps */
        int dir = (target > from) ? 1 : -1;
        for (int v = from; v != target; v += dir*5) {
            if (dir==1 && v>target) v=target;
            if (dir==-1 && v<target) v=target;
            char buf[32]; snprintf(buf,sizeof(buf),"%d",v);
            /* apply to all */
            for (int i=0;i<npwm;i++){
                char en[128]; snprintf(en,sizeof(en),"%s_enable",pwms[i]);
                write_file(en,"1");
                int m=255; char mx[128]; snprintf(mx,sizeof(mx),"%s_max",pwms[i]); read_int(mx,&m);
                char val[32]; snprintf(val,sizeof(val),"%d",(int)((long long)m*v/100));
                write_file(pwms[i],val);
            }
            usleep(step_us<1?10000:step_us/100);
        }
        printf("ok=ramped:%d%%\n", target);
        return 0;
    }

    if (strcmp(cmd, "pulse") == 0 && argc >= 4) {
        int hz = atoi(argv[2]);
        int dur_ms = atoi(argv[3]);
        /* oscillate between 100% and 10% rapidly (dust dislodger) */
        find_pwms(pwms, &npwm);
        if (npwm==0) { fprintf(stderr,"no PWM for pulse\n"); return 1; }
        unsigned long iterations = (unsigned long)((long long)hz * dur_ms / 1000);
        if (iterations > 100000) iterations = 100000;
        long half_us = 1000000L / (hz * 2);
        for (unsigned long i=0;i<iterations;i++){
            int target = (i%2)?10:100;
            for (int k=0;k<npwm;k++){
                char en[128]; snprintf(en,sizeof(en),"%s_enable",pwms[k]);
                write_file(en,"1");
                int m=255; char mx[128]; snprintf(mx,sizeof(mx),"%s_max",pwms[k]); read_int(mx,&m);
                char val[32]; snprintf(val,sizeof(val),"%d",(int)((long long)m*target/100));
                write_file(pwms[k],val);
            }
            usleep(half_us);
        }
        printf("ok=pulsed:%dHz for %dms\n", hz, dur_ms);
        return 0;
    }

    if (strcmp(cmd, "auto") == 0) {
        find_pwms(pwms, &npwm);
        int wrote = 0;
        for (int i=0;i<npwm;i++){
            char en[128]; snprintf(en,sizeof(en),"%s_enable",pwms[i]);
            if (write_file(en,"2")==0) wrote++;
        }
        printf("ok=auto:%d fans\n", wrote);
        return 0;
    }

    fprintf(stderr, "unknown command\n");
    return 2;
}
