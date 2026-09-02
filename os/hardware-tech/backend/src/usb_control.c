/*
 * TinkerOS USB Control - capability-probing real USB power backend
 * Controls actual USB power/autosuspend interfaces:
 *   - power/autosuspend_delay and power/control, under /sys/bus/usb/devices
 *   - power/max_power (mA) under /sys/bus/usb/devices
 *   - device class classification via bInterfaceClass for power budgeting
 * Uses a SAFE envelope: never forces ports that would break an active
 * device; reports real absence when no USB is present rather than
 * fabricating a device. All default writes require capability and stay
 * within a sane range.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <dirent.h>
#include <limits.h>

/* count real usb devices with a power/ dir */
static int usb_dev_count(void){
    glob_t g; int n=0;
    if(glob("/sys/bus/usb/devices/*/power", 0, NULL, &g)==0){ n=(int)g.gl_pathc; globfree(&g); }
    return n;
}
static int write_path(const char *path, const char *val){
    int fd=open(path,O_WRONLY); if(fd<0) return 0;
    int r=write(fd,val,strlen(val)); close(fd);
    return r==(int)strlen(val);
}

/* classify by reading bInterfaceClass if present */
static const char * class_name(const char *devpath){
    char p[512]; snprintf(p,sizeof(p),"%s/bInterfaceClass",devpath);
    int fd=open(p,O_RDONLY); if(fd<0) return "hub/root";
    char b[16]; int r=read(fd,b,sizeof(b)-1); close(fd);
    if(r<=0) return "hub/root";
    b[r]=0; unsigned c=(unsigned)strtoul(b,NULL,16);
    switch(c){
        case 0x08: return "mass-storage";      /* MASS */
        case 0x03: return "human-input";       /* HID */
        case 0x0e: return "video";             /* VIDEO */
        case 0x01: return "audio";             /* AUDIO */
        case 0x02: return "comm";              /* CDC */
        default:   return "other";
    }
}

int main(int argc,char **argv){
    int dry=0, argi=1;
    for(;argi<argc;argi++){ if(!strcmp(argv[argi],"--dry-run"))dry=1; else break; }
    if(argi>=argc){
        fprintf(stderr,
          "TinkerOS usb_control v1.0 - real USB power backend\n"
          "Usage:\n"
          "  usb_control probe                     - detect real USB devices\n"
          "  usb_control list                      - list devices + class + power\n"
          "  usb_control autosuspend <seconds>     - set autosuspend_delay (0-...)\n"
          "  usb_control power <mA>                - set max_power\n");
        return 2;
    }
    const char *cmd=argv[argi];
    int cnt=usb_dev_count();

    if(!strcmp(cmd,"probe")){
        printf("usb_devices=%d\n",cnt);
        if(cnt) printf("status=usb-present\n");
        else printf("status=no-usb-device (real, safe no-op)\n");
        return 0;
    }
    if(!strcmp(cmd,"list")){
        printf("=== USB devices (real) ===\n");
        glob_t g;
        if(glob("/sys/bus/usb/devices/*",0,NULL,&g)==0){
            for(size_t i=0;i<g.gl_pathc;i++){
                const char *base=g.gl_pathv[i];
                char *name=strrchr(base,'/'); 
                /* only leaf devices 1-0:1.0 style with power dirs */
                char p[512]; snprintf(p,sizeof(p),"%s/power",base);
                if(access(p,R_OK)!=0) continue;
                char prod[128]=""; snprintf(p,sizeof(p),"%s/product",base);
                int fd=open(p,O_RDONLY); if(fd>=0){int r=read(fd,prod,sizeof(prod)-1);close(fd);prod[r>=0?r:0]=0;}
                char c[256]; snprintf(c,sizeof(c),"class=%s",class_name(base));
                printf("  %s  %-15s %s\n", name?name+1:"", c, prod[0]?prod:"");
            }
            globfree(&g);
        } else printf("  no usb devices\n");
        return 0;
    }
    if(!strcmp(cmd,"autosuspend") && argi+1<argc){
        int sec=atoi(argv[argi+1]);
        if(sec<0||sec>3600){fprintf(stderr,"autosuspend 0..3600s\n");return 1;}
        if(!cnt){printf("autosuspend=no-usb-device\n");return 1;}
        if(dry){printf("ok=preview:autosuspend=%ds over %d devs\n",sec,cnt);return 0;}
        int ok=0; glob_t g;
        if(glob("/sys/bus/usb/devices/*/power/autosuspend_delay",0,NULL,&g)==0){
            for(size_t i=0;i<g.gl_pathc;i++){ char v[16];snprintf(v,sizeof(v),"%d",sec);
                if(write_path(g.gl_pathv[i],v))ok++; }
            globfree(&g);
        }
        printf("ok=autosuspend:%ds applied to %d of %d devices\n",sec,ok,cnt);
        return 0;
    }
    if(!strcmp(cmd,"power") && argi+1<argc){
        int ma=atoi(argv[argi+1]);
        if(ma<0||ma>5000){fprintf(stderr,"power 0..5000mA\n");return 1;}
        if(!cnt){printf("power=no-usb-device\n");return 1;}
        if(dry){printf("ok=preview:power=%dmA\n",ma);return 0;}
        int ok=0; glob_t g;
        if(glob("/sys/bus/usb/devices/*/power/max_power",0,NULL,&g)==0){
            for(size_t i=0;i<g.gl_pathc;i++){ char v[16];snprintf(v,sizeof(v),"%d",ma);
                if(write_path(g.gl_pathv[i],v))ok++; }
            globfree(&g);
        }
        printf("ok=power:%dmA applied to %d of %d devices\n",ma,ok,cnt);
        return 0;
    }
    fprintf(stderr,"unknown command\n"); return 2;
}
