// SPDX-License-Identifier: GPL-2.0
#ifndef _TINKER_CORE_H
#define _TINKER_CORE_H

#include <linux/proc_fs.h>

/*
 * TinkerOS core kernel features — shared declarations.
 *
 * The core module provides the /proc/tinker directory and status file;
 * individual feature modules register their own nodes beneath it.
 */

extern struct proc_dir_entry *tinker_proc_root;
struct task_struct;

#ifdef CONFIG_TINKER_THERMAL_SCHED
extern void tinker_thermal_hint_hot_cpu(int cpu);
extern bool tinker_thermal_is_hot(int cpu);
#endif

#ifdef CONFIG_TINKER_GAMEMODE
extern void tinker_gamemode_request_boost(pid_t tgid, int on);
extern bool tinker_gamemode_enabled(void);
extern bool tinker_task_boosted(struct task_struct *p);
extern void tinker_gamemode_reap_finished(void);
#endif

#ifdef CONFIG_TINKER_ENERGY_SCHED
extern void tinker_energy_account(u64 idle, u64 busy);
#define TINKER_ENERGY_AUTO	0
#define TINKER_ENERGY_PEAK	1
#define TINKER_ENERGY_SAVER	2
extern int tinker_energy_mode(void);
#endif

#ifdef CONFIG_TINKER_OLED_WEAR
extern unsigned int tinker_oled_get_dim(void);
#endif

#ifdef CONFIG_TINKER_BATTERY_LIFE
extern bool tinker_battery_lifespan(void);
extern void tinker_battery_envelope(int *lo, int *hi);
#endif

#endif /* _TINKER_CORE_H */
