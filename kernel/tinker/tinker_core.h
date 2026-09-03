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

#ifdef CONFIG_TINKER_THERMAL_SCHED
extern void tinker_thermal_hint_hot_cpu(int cpu);
#endif

#ifdef CONFIG_TINKER_GAMEMODE
extern void tinker_gamemode_request_boost(pid_t tgid, int on);
#endif

#ifdef CONFIG_TINKER_ENERGY_SCHED
extern void tinker_energy_account(u64 idle, u64 busy);
#endif

#endif /* _TINKER_CORE_H */
