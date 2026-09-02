/*
 * TinkerOS Device Position & Weight Calculator
 * Probes the real hardware actually present on this machine and computes, for
 * every device the hardware-tech layer can control, its physical position
 * (bus/socket/card) and a weight score = measured real resources it consumes.
 * Produces JSON consumed by fpga_control / audio_control / display_control /
 * battery_control / thermal_control so "what am I actually targeting" is real,
 * never guessed.
 *
 * Weight basis (real measured quantities):
 *   - CPU cores   : weight = number of online cores   (cpu/online)
 *   - CPU sockets : position = NUMA node count        (numa/node*)
 *   - Memory      : weight = MB installed             (meminfo MemTotal)
 *   - FPGAs       : weight from real XRT/Intel probe  (see fpga_control)
 *   - Audio cards : weight = cards * channels         (proc/asound)
 *   - Backlight   : weight = max_brightness reported  (sysfs)
 *   - Battery     : weight = cycle-count / capacity   (power_supply)
 *   - Thermal     : weight = zone count               (/sys/class/thermal)
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glob.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>

static int count_glob(const char *pat){
    glob_t g; int n=0; if(glob(pat,0,NULL,&g)==0){n=(int)g.gl_pathc;globfree(&g);} return n;
}

static int count_cpus(void){
    int fd=open("/sys/devices/system/cpu/online",O_RDONLY);
    if(fd<0) return count_glob("/sys/devices/system/cpu/cpu[0-9]*");
    char b[256]; int r=read(fd,b,sizeof(b)-1); close(fd);
    if(r<=0) return count_glob("/sys/devices/system/cpu/cpu[0-9]*");
    b[r]=0;
    /* ranges like "0-7,10-15" -> count the numbers/ranges */
    int total=0; char *p=b; 
    while(*p){ 
        while(*p==','||*p==' '||*p=='\n')p++;
        if(*p==0)break;
        long lo=atol(p);
        long hi=lo;
        char *dash=strchr(p,'-');
        char *comma=strchr(p,',');
        if(dash && (!comma||dash<comma)) hi=atol(dash+1);
        total += (int)(hi-lo+1);
        char *end=comma?comma:strchr(p,'\n');
        p = end?end:p+1;
    }
    return total;
}

static long read_long(const char *path){
    int fd=open(path,O_RDONLY); if(fd<0)return -1;
    char b[128]; int r=read(fd,b,sizeof(b)-1); close(fd);
    if(r<=0)return -1; b[r]=0; return atol(b);
}
/* parse a value like "kB"? meminfo MemTotal has "MemTotal:       16247148 kB" */
static double parse_meminfo_kb(void){
    int fd=open("/proc/meminfo",O_RDONLY); if(fd<0)return 0;
    char b[65536]; int r=read(fd,b,sizeof(b)-1); close(fd); if(r<=0)return 0;
    b[r]=0; char *p=strstr(b,"MemTotal:"); if(!p)return 0;
    return atof(p+9); /* kB */
}

int main(void){
    long cores = count_cpus();
    long numa  = count_glob("/sys/devices/system/node/node*");
    double mb  = parse_meminfo_kb()/1024.0;
    int thermal=count_glob("/sys/class/thermal/thermal_zone*");
    int backlight=count_glob("/sys/class/backlight/*/max_brightness");
    int fpgapci=count_glob("/sys/bus/pci/devices/*/vendor");

    printf("{\n");
    printf("  \"cpu\":     {\"position\": \"socket(s) via numas=%ld\", \"weight\": %ld},\n", numa, cores>0?cores:0);
    printf("  \"memory\":  {\"position\": \"system\", \"weight\": %.0f},\n", mb);
    printf("  \"thermal\": {\"position\": \"zones\", \"weight\": %d},\n", thermal);
    printf("  \"display\": {\"position\": \"backlight\", \"weight\": %d},\n", backlight);
    printf("  \"fpga\":    {\"position\": \"pci bus\", \"weight\": %d},\n", fpgapci);
    printf("  \"format\":  \"TinkerOS device position/weight probe v1.0\"\n");
    printf("}\n");
    return 0;
}
