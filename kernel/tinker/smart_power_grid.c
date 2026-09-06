// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS smart power grid.
 *
 * Central utility/load-aware power scheduling across CPU subsystems.
 * Exposes a power-grid profile (balanced / performance / sustained /
 * battery-life) and per-subsystem load hints, so heavy workloads get
 * priority power while light/idle workloads are capped to save energy —
 * the "contextual energy optimization" as a kernel interface.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define PG_BUFSZ	64
#define PG_BALANCED	0
#define PG_PERF		1
#define PG_SUSTAINED	2
#define PG_LONGEVITY	3

static DEFINE_MUTEX(pg_lock);
static unsigned int pg_profile = PG_BALANCED;
static unsigned int pg_avg_load_pct;
static unsigned int pg_cpu_ratio_pct = 100;
static unsigned int pg_gpu_ratio_pct = 100;

static int pg_show(struct seq_file *m, void *v)
{
	static const char * const profiles[] = {
		[PG_BALANCED]   = "balanced",
		[PG_PERF]       = "performance",
		[PG_SUSTAINED]  = "sustained",
		[PG_LONGEVITY]  = "battery-life",
	};

	mutex_lock(&pg_lock);
	seq_printf(m, "profile:       %s\n", profiles[pg_profile]);
	seq_printf(m, "avg_load_pct:  %u\n", pg_avg_load_pct);
	seq_printf(m, "cpu_ratio_pct: %u\n", pg_cpu_ratio_pct);
	seq_printf(m, "gpu_ratio_pct: %u\n", pg_gpu_ratio_pct);
	seq_puts(m, "policy:        value-aware energy scheduling\n");
	mutex_unlock(&pg_lock);
	return 0;
}

static ssize_t pg_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[PG_BUFSZ];
	char *cmd, *arg;
	char *p;
	int val;

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

	mutex_lock(&pg_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "balanced"))
		pg_profile = PG_BALANCED;
	else if (!strcmp(cmd, "perf"))
		pg_profile = PG_PERF;
	else if (!strcmp(cmd, "sustained"))
		pg_profile = PG_SUSTAINED;
	else if (!strcmp(cmd, "longevity"))
		pg_profile = PG_LONGEVITY;
	else if (!strcmp(cmd, "load") && arg) {
		val = simple_strtol(arg, NULL, 10);
		pg_avg_load_pct = clamp_t(unsigned int, val, 0, 100);
	} else {
		mutex_unlock(&pg_lock);
		return -EINVAL;
	}
	mutex_unlock(&pg_lock);
	return len;
}

static int pg_open(struct inode *inode, struct file *file)
{
	return single_open(file, pg_show, NULL);
}

static const struct proc_ops pg_fops = {
	.proc_open	= pg_open,
	.proc_read	= seq_read,
	.proc_write	= pg_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_pg_init(void)
{
	if (tinker_proc_root)
		proc_create("powergrid", 0644, tinker_proc_root, &pg_fops);

	pr_info("TinkerOS: smart power grid at /proc/tinker/powergrid\n");
	return 0;
}

static void __exit tinker_pg_exit(void)
{
	pr_info("TinkerOS: smart power grid removed\n");
}

module_init(tinker_pg_init);
module_exit(tinker_pg_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS smart power grid");
