// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS thermal-aware scheduling hints.
 *
 * Implements the "silicon thermal mapping" concept as a real kernel
 * feature: maintain a live per-CPU heat map, expose it via
 * /proc/tinker/thermal, and let the scheduler treat hot cores as lower
 * preference for new load. The map is fed by the scheduler (marking
 * overloaded cores) plus a periodic decay so the signal self-heals.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/percpu.h>
#include <linux/smp.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include <linux/uaccess.h>
#include <linux/workqueue.h>
#include <linux/fs.h>
#include <linux/namei.h>
#include <linux/uaccess.h>
#include <linux/sched.h>

#include "tinker_core.h"

#define THERMAL_MAX_ZONES	8
#define THERMAL_BUF_SZ		32

struct tinker_heat_map {
	unsigned int		zones;
	unsigned long		last_sample;
	/* per-cpu rolling temperature estimate in millicelsius */
	u64			cpu_temp_mc[NR_CPUS];
	u64			cpu_hot_thresh_mc;
	unsigned int		enabled;
	u64			zone_temps[THERMAL_MAX_ZONES];
};

static struct tinker_heat_map heat;
static DEFINE_MUTEX(thermal_lock);	/* guards seq_file show() */
static DEFINE_SPINLOCK(thermal_map_lock); /* guards cpu_temp_mc[cpu] */
static struct delayed_work thermal_decay_work;

/* Mark a CPU hot; decay brings it back down over time. */
void tinker_thermal_hint_hot_cpu(int cpu)
{
	unsigned long flags;

	if (!heat.enabled || cpu < 0 || cpu >= nr_cpu_ids)
		return;

	spin_lock_irqsave(&thermal_map_lock, flags);
	if (heat.cpu_temp_mc[cpu] < heat.cpu_hot_thresh_mc)
		heat.cpu_temp_mc[cpu] = heat.cpu_hot_thresh_mc + 1000;
	spin_unlock_irqrestore(&thermal_map_lock, flags);
}
EXPORT_SYMBOL_GPL(tinker_thermal_hint_hot_cpu);

/* Query used by the scheduler: should this CPU be avoided for new load? */
bool tinker_thermal_is_hot(int cpu)
{
	unsigned long flags;
	bool hot;

	if (!heat.enabled || cpu < 0 || cpu >= nr_cpu_ids)
		return false;

	spin_lock_irqsave(&thermal_map_lock, flags);
	hot = heat.cpu_temp_mc[cpu] > heat.cpu_hot_thresh_mc;
	spin_unlock_irqrestore(&thermal_map_lock, flags);
	return hot;
}
EXPORT_SYMBOL_GPL(tinker_thermal_is_hot);

/* Cool the map back toward zero so the heat signal self-heals. */
static void thermal_decay_workfn(struct work_struct *work)
{
	unsigned long flags;
	int cpu;
	unsigned int i;
	char path[64];
	char buf[THERMAL_BUF_SZ];
	struct file *f;
	loff_t pos = 0;
	ssize_t nr;
	long temp_mc;

	/* Read real thermal zone temperatures and blend them in */
	for (i = 0; i < THERMAL_MAX_ZONES; i++) {
		snprintf(path, sizeof(path),
			 "/sys/class/thermal/thermal_zone%u/temp", i);
		f = filp_open(path, O_RDONLY, 0);
		if (IS_ERR(f))
			break;
		memset(buf, 0, sizeof(buf));
		nr = kernel_read(f, buf, sizeof(buf) - 1, &pos);
		filp_close(f, NULL);
		if (nr > 0) {
			buf[nr] = '\0';
			if (kstrtol(buf, 10, &temp_mc) == 0) {
				/* Kernel thermal zones report millidegrees */
				if (temp_mc < 200)
					temp_mc *= 1000;
				heat.zone_temps[i] = temp_mc;
			}
		}
	}
	heat.zones = i;

	spin_lock_irqsave(&thermal_map_lock, flags);
	for_each_possible_cpu(cpu) {
		/* Blend: average real zone temp with hint-based estimate */
		if (heat.zones > 0 && cpu < heat.zones) {
			heat.cpu_temp_mc[cpu] =
				(heat.cpu_temp_mc[cpu] + heat.zone_temps[cpu]) / 2;
		}
		/* Decay toward zero */
		if (heat.cpu_temp_mc[cpu] > 0)
			heat.cpu_temp_mc[cpu] -= 500;
	}
	spin_unlock_irqrestore(&thermal_map_lock, flags);

	schedule_delayed_work(&thermal_decay_work,
			      msecs_to_jiffies(5000));
}

static int thermal_show(struct seq_file *m, void *v)
{
	unsigned long flags;
	int cpu;
	unsigned int enabled;

	mutex_lock(&thermal_lock);
	enabled = heat.enabled;
	seq_printf(m, "enabled:        %u\n", enabled);
	seq_printf(m, "zones:          %u\n", heat.zones);
	seq_printf(m, "hot_threshold:  %llu mc\n",
		   (unsigned long long)heat.cpu_hot_thresh_mc);
	seq_puts(m, "cpu_temp_mc:\n");
	spin_lock_irqsave(&thermal_map_lock, flags);
	for_each_possible_cpu(cpu)
		seq_printf(m, "  cpu%d:       %llu mc\n", cpu,
			   (unsigned long long)heat.cpu_temp_mc[cpu]);
	spin_unlock_irqrestore(&thermal_map_lock, flags);
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

static int __init tinker_thermal_init(void)
{
	heat.cpu_hot_thresh_mc = 80000; /* 80 C default */
	heat.enabled = 1;
	heat.zones = 1;

	INIT_DELAYED_WORK(&thermal_decay_work, thermal_decay_workfn);
	schedule_delayed_work(&thermal_decay_work, msecs_to_jiffies(5000));

	if (tinker_proc_root)
		proc_create("thermal", 0644, tinker_proc_root, &thermal_fops);

	pr_info("TinkerOS: thermal scheduler interface at /proc/tinker/thermal\n");
	return 0;
}

static void __exit tinker_thermal_exit(void)
{
	cancel_delayed_work_sync(&thermal_decay_work);
	pr_info("TinkerOS: thermal scheduler interface removed\n");
}

module_init(tinker_thermal_init);
module_exit(tinker_thermal_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS thermal-aware scheduling hints");
