// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS neural super-resolution — upscale DSP frontend.
 *
 * Exposes an upscaling profile (target scale, sharpness, model tier)
 * and per-frame metrics. Heavy neural upscale runs in user space
 * reading these settings; the kernel provides the processing profile.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define NSR_BUFSZ	64

static DEFINE_MUTEX(nsr_lock);
static unsigned int nsr_enabled;
static unsigned int nsr_scale = 2;	/* 1x, 2x, 4x */
static unsigned int nsr_sharpness = 50;
static unsigned long long nsr_frames;

static int nsr_show(struct seq_file *m, void *v)
{
	mutex_lock(&nsr_lock);
	seq_printf(m, "enabled:          %u\n", nsr_enabled);
	seq_printf(m, "scale:            %ux\n", nsr_scale);
	seq_printf(m, "sharpness:        %u\n", nsr_sharpness);
	seq_printf(m, "frames:           %llu\n", nsr_frames);
	seq_puts(m, "engine:           neural upscale frontend\n");
	mutex_unlock(&nsr_lock);
	return 0;
}

static ssize_t nsr_write(struct file *file, const char __user *ubuf,
			 size_t len, loff_t *ppos)
{
	char buf[NSR_BUFSZ];
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

	mutex_lock(&nsr_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on"))
		nsr_enabled = 1;
	else if (!strcmp(cmd, "off"))
		nsr_enabled = 0;
	else if (!strcmp(cmd, "scale") && arg) {
		val = simple_strtol(arg, NULL, 10);
		nsr_scale = (val == 1 || val == 2 || val == 4) ? val : 2;
	} else if (!strcmp(cmd, "frame"))
		nsr_frames++;
	else {
		mutex_unlock(&nsr_lock);
		return -EINVAL;
	}
	mutex_unlock(&nsr_lock);
	return len;
}

static int nsr_open(struct inode *inode, struct file *file)
{
	return single_open(file, nsr_show, NULL);
}

static const struct proc_ops nsr_fops = {
	.proc_open	= nsr_open,
	.proc_read	= seq_read,
	.proc_write	= nsr_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_nsr_init(void)
{
	if (tinker_proc_root)
		proc_create("nsr", 0644, tinker_proc_root, &nsr_fops);

	pr_info("TinkerOS: neural super-res at /proc/tinker/nsr\n");
	return 0;
}

static void __exit tinker_nsr_exit(void)
{
	pr_info("TinkerOS: neural super-res removed\n");
}

module_init(tinker_nsr_init);
module_exit(tinker_nsr_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS neural super-resolution");
