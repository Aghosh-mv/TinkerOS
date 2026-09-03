// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS hardware tuning — low-level tuning farm.
 *
 * Central knob for CPU/GPU/I/O tuning parameters (governor hint,
 * overclock intent, fan curve, latency mode). Exposes a single
 * /proc/tinker/tuning interface, consent-gated for risky items.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define TUNE_BUFSZ	64

static DEFINE_MUTEX(tune_lock);
static unsigned int tune_governor;	/* 0 auto, 1 performance, 2 powersave */
static bool tune_overclock_intent;
static unsigned int tune_fan_curve;	/* 0-100 aggressiveness */

static int tune_show(struct seq_file *m, void *v)
{
	mutex_lock(&tune_lock);
	seq_printf(m, "governor:        %u\n", tune_governor);
	seq_printf(m, "overclock_intent:%u\n", tune_overclock_intent);
	seq_printf(m, "fan_curve:       %u\n", tune_fan_curve);
	seq_puts(m, "policy:          low-level tuning farm\n");
	seq_puts(m, "consent:         risky items explicit-toggle only\n");
	mutex_unlock(&tune_lock);
	return 0;
}

static ssize_t tune_write(struct file *file, const char __user *ubuf,
			  size_t len, loff_t *ppos)
{
	char buf[TUNE_BUFSZ];
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

	mutex_lock(&tune_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "gov") && arg) {
		val = simple_strtol(arg, NULL, 10);
		tune_governor = (val > 2) ? 0 : val;
	} else if (!strcmp(cmd, "oc") && arg) {
		val = simple_strtol(arg, NULL, 10);
		tune_overclock_intent = val ? 1 : 0;
	} else if (!strcmp(cmd, "fan") && arg) {
		val = simple_strtol(arg, NULL, 10);
		tune_fan_curve = clamp_t(unsigned int, val, 0, 100);
	} else {
		mutex_unlock(&tune_lock);
		return -EINVAL;
	}
	mutex_unlock(&tune_lock);
	return len;
}

static int tune_open(struct inode *inode, struct file *file)
{
	return single_open(file, tune_show, NULL);
}

static const struct proc_ops tune_fops = {
	.proc_open	= tune_open,
	.proc_read	= seq_read,
	.proc_write	= tune_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_tune_init(void)
{
	if (tinker_proc_root)
		proc_create("tuning", 0644, tinker_proc_root, &tune_fops);

	pr_info("TinkerOS: hardware tuning at /proc/tinker/tuning\n");
	return 0;
}

static void __exit tinker_tune_exit(void)
{
	pr_info("TinkerOS: hardware tuning removed\n");
}

module_init(tinker_tune_init);
module_exit(tinker_tune_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS low-level hardware tuning");
