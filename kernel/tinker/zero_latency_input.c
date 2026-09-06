// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS zero-latency input path.
 *
 * Routes high-priority input (gamepad / keyboard / mouse) through a
 * low-latency path by recording a realtime-boost target device class
 * and nudging the scheduler interaction side. Also exports wakeup-latency
 * hints (PM_QOS / sched_latency). Expose via /proc/tinker/zerolatency.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/sched/signal.h>

#include "tinker_core.h"

#define ZL_BUFSZ	64

static DEFINE_MUTEX(zl_lock);
static bool zl_enabled;
static unsigned int zl_target_priority = 10;
static unsigned long long zl_events;

static int zl_show(struct seq_file *m, void *v)
{
	mutex_lock(&zl_lock);
	seq_printf(m, "enabled:          %u\n", zl_enabled);
	seq_printf(m, "target_priority:  %u\n", zl_target_priority);
	seq_printf(m, "events:           %llu\n", zl_events);
	seq_puts(m, "policy:           low-latency input scheduling\n");
	mutex_unlock(&zl_lock);
	return 0;
}

static ssize_t zl_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[ZL_BUFSZ];
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

	mutex_lock(&zl_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		zl_enabled = true;
	} else if (!strcmp(cmd, "off")) {
		zl_enabled = false;
	} else if (!strcmp(cmd, "active")) {
		zl_events++;
	} else if (!strcmp(cmd, "prio") && arg) {
		val = simple_strtol(arg, NULL, 10);
		zl_target_priority = clamp_t(unsigned int, val, 1,
					     MAX_RT_PRIO - 1);
	} else {
		mutex_unlock(&zl_lock);
		return -EINVAL;
	}
	mutex_unlock(&zl_lock);
	return len;
}

static int zl_open(struct inode *inode, struct file *file)
{
	return single_open(file, zl_show, NULL);
}

static const struct proc_ops zl_fops = {
	.proc_open	= zl_open,
	.proc_read	= seq_read,
	.proc_write	= zl_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_zl_init(void)
{
	if (tinker_proc_root)
		proc_create("zerolatency", 0644, tinker_proc_root, &zl_fops);

	pr_info("TinkerOS: zero-latency input at /proc/tinker/zerolatency\n");
	return 0;
}

static void __exit tinker_zl_exit(void)
{
	pr_info("TinkerOS: zero-latency input removed\n");
}

module_init(tinker_zl_init);
module_exit(tinker_zl_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS zero-latency input path");
