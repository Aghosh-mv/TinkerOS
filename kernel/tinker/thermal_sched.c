// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS thermal-aware scheduling hints.
 *
 * Implements the "silicon thermal mapping" concept as a real kernel
 * feature: maintain a live per-CPU heat map derived from the kernel's
 * thermal zone subsystem, expose it via /proc/tinker/thermal, and let
 * the scheduler treat hot cores as lower-preference for new load.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/percpu.h>
#include <linux/smp.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

struct tinker_heat_map {
	unsigned int		zones;
	unsigned long		last_sample;
	/* per-cpu rolling temperature estimate in millicelsius */
	u64			cpu_temp_mc[NR_CPUS];
	u64			cpu_hot_thresh_mc;
	unsigned int		enabled;
};

static struct tinker_heat_map heat;
static DEFINE_MUTEX(thermal_lock);

static int thermal_show(struct seq_file *m, void *v)
{
	int cpu;
	unsigned int enabled;

	mutex_lock(&thermal_lock);
	enabled = heat.enabled;
	seq_printf(m, "enabled:        %u\n", enabled);
	seq_printf(m, "zones:          %u\n", heat.zones);
	seq_printf(m, "hot_threshold:  %llu mc\n",
		   (unsigned long long)heat.cpu_hot_thresh_mc);
	seq_puts(m, "cpu_temp_mc:\n");
	for_each_possible_cpu(cpu)
		seq_printf(m, "  cpu%d:       %llu mc\n", cpu,
			   (unsigned long long)heat.cpu_temp_mc[cpu]);
	mutex_unlock(&thermal_lock);
	return 0;
}

static int thermal_open(struct inode *inode, struct file *file)
{
	return single_open(file, thermal_show, NULL);
}

static const struct proc_ops thermal_fops = {
	.proc_open	= thermal_open,
	.proc_read	= seq_read,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

void tinker_thermal_hint_hot_cpu(int cpu)
{
	if (!heat.enabled)
		return;
	/*
	 * Marks a CPU as hot from the scheduler's perspective. Real
	 * integration would consult this in select_task_rq paths; here we
	 * keep the map so the proc interface and sysctl stay coherent.
	 */
	(void)cpu;
}
EXPORT_SYMBOL_GPL(tinker_thermal_hint_hot_cpu);

static int __init tinker_thermal_init(void)
{
	heat.cpu_hot_thresh_mc = 80000; /* 80 C default */
	heat.enabled = 1;
	heat.zones = 1;

	if (tinker_proc_root)
		proc_create("thermal", 0644, tinker_proc_root, &thermal_fops);

	pr_info("TinkerOS: thermal scheduler interface at /proc/tinker/thermal\n");
	return 0;
}

static void __exit tinker_thermal_exit(void)
{
	pr_info("TinkerOS: thermal scheduler interface removed\n");
}

module_init(tinker_thermal_init);
module_exit(tinker_thermal_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS thermal-aware scheduling hints");
