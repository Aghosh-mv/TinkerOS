// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS core kernel interface.
 *
 * Provides the central /proc/tinker directory and per-feature control
 * nodes. This is the kernel-internal home for the TinkerOS control
 * center: hardware-throughput-code desktop features expressed as real
 * kernel C code rather than user-space-only tools.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/utsname.h>
#include <linux/version.h>
#include <linux/string.h>

#define TINKER_PROC_DIR "tinker"

struct proc_dir_entry *tinker_proc_root;

static int tinker_status_show(struct seq_file *m, void *v)
{
	seq_printf(m, "TinkerOS core kernel features\n");
	seq_printf(m, "kernel:   %s\n", utsname()->release);
#ifdef CONFIG_TINKER_THERMAL_SCHED
	seq_puts(m, "thermal:  available (TINKER_THERMAL_SCHED)\n");
#endif
#ifdef CONFIG_TINKER_GAMEMODE
	seq_puts(m, "gamemode: available (TINKER_GAMEMODE)\n");
#endif
#ifdef CONFIG_TINKER_ENERGY_SCHED
	seq_puts(m, "energy:   available (TINKER_ENERGY_SCHED)\n");
#endif
#ifdef CONFIG_TINKER_BATTERY_LIFE
	seq_puts(m, "battery:  available (TINKER_BATTERY_LIFE)\n");
#endif
#ifdef CONFIG_TINKER_OLED_WEAR
	seq_puts(m, "oled:     available (TINKER_OLED_WEAR)\n");
#endif
	return 0;
}

static int tinker_status_open(struct inode *inode, struct file *file)
{
	return single_open(file, tinker_status_show, NULL);
}

static const struct proc_ops tinker_status_fops = {
	.proc_open	= tinker_status_open,
	.proc_read	= seq_read,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_init(void)
{
	tinker_proc_root = proc_mkdir(TINKER_PROC_DIR, NULL);
	if (!tinker_proc_root)
		return -ENOMEM;

	proc_create("status", 0444, tinker_proc_root, &tinker_status_fops);
	pr_info("TinkerOS: core interface mounted at /proc/tinker\n");
	return 0;
}

static void __exit tinker_exit(void)
{
	proc_remove(tinker_proc_root);
	pr_info("TinkerOS: core interface removed\n");
}

module_init(tinker_init);
module_exit(tinker_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("TinkerOS");
MODULE_DESCRIPTION("TinkerOS core kernel features");
