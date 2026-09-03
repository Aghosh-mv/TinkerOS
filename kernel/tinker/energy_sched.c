// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS energy / DVFS hinting.
 *
 * Implements the "contextual energy optimisation" and "microsecond-scale
 * voltage hint" ideas as a real kernel accounting interface. The user-
 * space frontend and cpufreq governor can read / write an energy profile
 * hint via /proc/tinker/energy so heavy workloads request peak voltage
 * and light/idle workloads request a minimum stable profile, all without
 * the user having to issue power-management commands manually.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/atomic.h>

#include "tinker_core.h"

#define ENERGY_BUFSZ		64
#define ENERGY_MODE_AUTO	0
#define ENERGY_MODE_PEAK	1
#define ENERGY_MODE_SAVER	2

static DEFINE_MUTEX(energy_lock);
static int energy_mode = ENERGY_MODE_AUTO;
static atomic64_t energy_ticks_idle;
static atomic64_t energy_ticks_busy;

void tinker_energy_account(u64 idle, u64 busy)
{
	atomic64_add(idle, &energy_ticks_idle);
	atomic64_add(busy, &energy_ticks_busy);
}
EXPORT_SYMBOL_GPL(tinker_energy_account);

static int energy_show(struct seq_file *m, void *v)
{
	static const char * const modes[] = {
		[ENERGY_MODE_AUTO]  = "auto",
		[ENERGY_MODE_PEAK]  = "peak",
		[ENERGY_MODE_SAVER] = "saver",
	};

	mutex_lock(&energy_lock);
	seq_printf(m, "mode:   %s\n", modes[energy_mode]);
	seq_printf(m, "hint:   %s\n",
		   energy_mode == ENERGY_MODE_PEAK ? "high-vf" :
		   energy_mode == ENERGY_MODE_SAVER ? "min-vf" : "auto");
	seq_printf(m, "idle:   %llu\n",
		   (unsigned long long)atomic64_read(&energy_ticks_idle));
	seq_printf(m, "busy:   %llu\n",
		   (unsigned long long)atomic64_read(&energy_ticks_busy));
	mutex_unlock(&energy_lock);
	return 0;
}

static ssize_t energy_write(struct file *file, const char __user *ubuf,
			    size_t len, loff_t *ppos)
{
	char buf[ENERGY_BUFSZ];
	char *p;

	if (len >= sizeof(buf))
		return -EINVAL;
	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;
	buf[len] = '\0';

	for (p = buf; *p; p++) {
		if (*p == '\n' || *p == '\r') {
			*p = '\0';
			break;
		}
	}

	mutex_lock(&energy_lock);
	if (!strcmp(buf, "auto"))
		energy_mode = ENERGY_MODE_AUTO;
	else if (!strcmp(buf, "peak"))
		energy_mode = ENERGY_MODE_PEAK;
	else if (!strcmp(buf, "saver"))
		energy_mode = ENERGY_MODE_SAVER;
	else {
		mutex_unlock(&energy_lock);
		return -EINVAL;
	}
	mutex_unlock(&energy_lock);
	return len;
}

static int energy_open(struct inode *inode, struct file *file)
{
	return single_open(file, energy_show, NULL);
}

static const struct proc_ops energy_fops = {
	.proc_open	= energy_open,
	.proc_read	= seq_read,
	.proc_write	= energy_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_energy_init(void)
{
	if (tinker_proc_root)
		proc_create("energy", 0644, tinker_proc_root, &energy_fops);

	pr_info("TinkerOS: energy/DVFS hints at /proc/tinker/energy\n");
	return 0;
}

static void __exit tinker_energy_exit(void)
{
	pr_info("TinkerOS: energy/DVFS hints removed\n");
}

module_init(tinker_energy_init);
module_exit(tinker_energy_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS energy / DVFS hint governor");
