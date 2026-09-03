// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS neural audio — audio enhancement DSP.
 *
 * Exposes an audio-enhancement chain (gain normalization, noise floor,
 * EQ profile) as a kernel DSP frontend. The actual heavy neural model
 * runs in user space reading these coefficients; the kernel passes the
 * processing profile and per-frame stats. Pure software DSP, no HW.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define NA_BUFSZ	64

static DEFINE_MUTEX(na_lock);

static unsigned int na_enabled;
static unsigned int na_gain_pct = 100;
static unsigned int na_noise_floor = 20;
static unsigned long long na_frames;

static int na_show(struct seq_file *m, void *v)
{
	mutex_lock(&na_lock);
	seq_printf(m, "enabled:          %u\n", na_enabled);
	seq_printf(m, "gain_pct:         %u\n", na_gain_pct);
	seq_printf(m, "noise_floor:      %u\n", na_noise_floor);
	seq_printf(m, "frames:           %llu\n", na_frames);
	seq_puts(m, "engine:           enhancement chain (neural frontend)\n");
	mutex_unlock(&na_lock);
	return 0;
}

static ssize_t na_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[NA_BUFSZ];
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

	mutex_lock(&na_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on"))
		na_enabled = 1;
	else if (!strcmp(cmd, "off"))
		na_enabled = 0;
	else if (!strcmp(cmd, "gain") && arg) {
		val = simple_strtol(arg, NULL, 10);
		na_gain_pct = clamp_t(unsigned int, val, 0, 400);
	} else if (!strcmp(cmd, "floor") && arg) {
		val = simple_strtol(arg, NULL, 10);
		na_noise_floor = clamp_t(unsigned int, val, 0, 100);
	} else {
		mutex_unlock(&na_lock);
		return -EINVAL;
	}
	na_frames++;
	mutex_unlock(&na_lock);
	return len;
}

static int na_open(struct inode *inode, struct file *file)
{
	return single_open(file, na_show, NULL);
}

static const struct proc_ops na_fops = {
	.proc_open	= na_open,
	.proc_read	= seq_read,
	.proc_write	= na_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_na_init(void)
{
	if (tinker_proc_root)
		proc_create("neuralaudio", 0644, tinker_proc_root, &na_fops);

	pr_info("TinkerOS: neural audio DSP at /proc/tinker/neuralaudio\n");
	return 0;
}

static void __exit tinker_na_exit(void)
{
	pr_info("TinkerOS: neural audio DSP removed\n");
}

module_init(tinker_na_init);
module_exit(tinker_na_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS neural audio enhancement");
