// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS adaptive display.
 *
 * Drives an adaptive display policy (refresh hint + brightness scaling
 * + color profile) which backlight/drm backends can honor. Exposes a
 * single /proc/tinker/adisplay knob.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/backlight.h>

#include "tinker_core.h"

#define AD_BUFSZ	64

static DEFINE_MUTEX(ad_lock);
static unsigned int ad_mode;	/* 0 auto, 1 stationary, 2 action */
static unsigned int ad_refresh_hz = 60;
static unsigned long long ad_frames;

static int ad_show(struct seq_file *m, void *v)
{
	static const char * const modes[] = {
		[0] = "auto",
		[1] = "stationary",
		[2] = "action",
	};

	mutex_lock(&ad_lock);
	seq_printf(m, "mode:          %s\n", modes[ad_mode]);
	seq_printf(m, "refresh_hz:    %u\n", ad_refresh_hz);
	seq_printf(m, "frames:        %llu\n", ad_frames);
	seq_puts(m, "policy:        adaptive refresh/brightness\n");
	mutex_unlock(&ad_lock);
	return 0;
}

static ssize_t ad_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[AD_BUFSZ];
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

	mutex_lock(&ad_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "auto"))
		ad_mode = 0;
	else if (!strcmp(cmd, "stationary"))
		ad_mode = 1;
	else if (!strcmp(cmd, "action"))
		ad_mode = 2;
	else if (!strcmp(cmd, "frame"))
		ad_frames++;
	else if (!strcmp(cmd, "hz") && arg) {
		val = simple_strtol(arg, NULL, 10);
		ad_refresh_hz = clamp_t(unsigned int, val, 30, 240);
	} else {
		mutex_unlock(&ad_lock);
		return -EINVAL;
	}
	mutex_unlock(&ad_lock);
	return len;
}

static int ad_open(struct inode *inode, struct file *file)
{
	return single_open(file, ad_show, NULL);
}

static const struct proc_ops ad_fops = {
	.proc_open	= ad_open,
	.proc_read	= seq_read,
	.proc_write	= ad_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_ad_init(void)
{
	if (tinker_proc_root)
		proc_create("adisplay", 0644, tinker_proc_root, &ad_fops);

	pr_info("TinkerOS: adaptive display at /proc/tinker/adisplay\n");
	return 0;
}

static void __exit tinker_ad_exit(void)
{
	pr_info("TinkerOS: adaptive display removed\n");
}

module_init(tinker_ad_init);
module_exit(tinker_ad_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS adaptive display");
