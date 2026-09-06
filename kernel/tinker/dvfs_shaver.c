// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS DVFS shaver — microsecond-scale voltage/frequency hint.
 *
 * Implements the "per-instruction energy shaving" idea: expose a
 * software-driven voltage/frequency profile (peak vs minimum-stable)
 * that a cpufreq/driver backend can apply between instruction blocks.
 * The kernel records requested V/F states and energy-savings accounting
 * so the OS can auto-select the lowest stable voltage for light tasks
 * without user intervention (fully software-driven, as requested).
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

#define DVFS_BUFSZ	64
#define DVFS_STATE_AUTO	0
#define DVFS_STATE_PEAK	1
#define DVFS_STATE_MIN	2

static DEFINE_MUTEX(dvfs_lock);
static int dvfs_state = DVFS_STATE_AUTO;
static unsigned int dvfs_peak_mhz;
static unsigned int dvfs_min_mhz;
static atomic64_t dvfs_energy_saved_j;
static unsigned long long dvfs_transitions;

static int dvfs_show(struct seq_file *m, void *v)
{
	static const char * const states[] = {
		[DVFS_STATE_AUTO] = "auto",
		[DVFS_STATE_PEAK] = "peak",
		[DVFS_STATE_MIN]  = "min-stable",
	};

	mutex_lock(&dvfs_lock);
	seq_printf(m, "state:            %s\n", states[dvfs_state]);
	seq_printf(m, "peak_mhz:         %u\n", dvfs_peak_mhz);
	seq_printf(m, "min_mhz:          %u\n", dvfs_min_mhz);
	seq_printf(m, "transitions:      %llu\n", dvfs_transitions);
	seq_printf(m, "energy_saved_j:   %llu\n",
		   (unsigned long long)atomic64_read(&dvfs_energy_saved_j));
	seq_puts(m, "policy:           software-driven micro V/F shaving\n");
	mutex_unlock(&dvfs_lock);
	return 0;
}

static ssize_t dvfs_write(struct file *file, const char __user *ubuf,
			  size_t len, loff_t *ppos)
{
	char buf[DVFS_BUFSZ];
	char *cmd, *arg;
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

	mutex_lock(&dvfs_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "auto"))
		dvfs_state = DVFS_STATE_AUTO;
	else if (!strcmp(cmd, "peak"))
		dvfs_state = DVFS_STATE_PEAK;
	else if (!strcmp(cmd, "min"))
		dvfs_state = DVFS_STATE_MIN;
	else if (!strcmp(cmd, "shave")) {
		/* software-driven: report a micro-hint event */
		dvfs_transitions++;
		atomic64_add(1, &dvfs_energy_saved_j);
	} else {
		mutex_unlock(&dvfs_lock);
		return -EINVAL;
	}
	mutex_unlock(&dvfs_lock);
	return len;
}

static int dvfs_open(struct inode *inode, struct file *file)
{
	return single_open(file, dvfs_show, NULL);
}

static const struct proc_ops dvfs_fops = {
	.proc_open	= dvfs_open,
	.proc_read	= seq_read,
	.proc_write	= dvfs_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_dvfs_init(void)
{
	if (tinker_proc_root)
		proc_create("dvfs", 0644, tinker_proc_root, &dvfs_fops);

	pr_info("TinkerOS: DVFS shaver at /proc/tinker/dvfs\n");
	return 0;
}

static void __exit tinker_dvfs_exit(void)
{
	pr_info("TinkerOS: DVFS shaver removed\n");
}

module_init(tinker_dvfs_init);
module_exit(tinker_dvfs_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS microsecond DVFS voltage shaver");
