// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS OLED burn-in wear compensation.
 *
 * Exposes a proportional backlight dimming path used by the display
 * layer to balance sub-pixel wear on OLED panels. The kernel tracks a
 * cumulative dim factor applied to the panel brightness so static UI
 * elements are not persistently driven at full luminance, reducing
 * uneven organic-LED degradation.
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

#define OLED_BUFSZ	64

static DEFINE_MUTEX(oled_lock);
static unsigned int oled_dim_pct = 100;	/* 100 = no dimming */
static unsigned long long oled_wear_seconds;

static int oled_show(struct seq_file *m, void *v)
{
	mutex_lock(&oled_lock);
	seq_printf(m, "dim_pct:       %u%%\n", oled_dim_pct);
	seq_printf(m, "wear_seconds:  %llu\n",
		   (unsigned long long)oled_wear_seconds);
	seq_printf(m, "policy:        proportional burn-in compensation\n");
	mutex_unlock(&oled_lock);
	return 0;
}

static ssize_t oled_write(struct file *file, const char __user *ubuf,
			  size_t len, loff_t *ppos)
{
	char buf[OLED_BUFSZ];
	int val;
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

	val = simple_strtol(buf, NULL, 10);
	if (val < 0 || val > 100)
		return -EINVAL;

	mutex_lock(&oled_lock);
	oled_dim_pct = val;
	mutex_unlock(&oled_lock);
	return len;
}

static int oled_open(struct inode *inode, struct file *file)
{
	return single_open(file, oled_show, NULL);
}

static const struct proc_ops oled_fops = {
	.proc_open	= oled_open,
	.proc_read	= seq_read,
	.proc_write	= oled_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_oled_init(void)
{
	if (tinker_proc_root)
		proc_create("oled", 0644, tinker_proc_root, &oled_fops);

	pr_info("TinkerOS: OLED wear compensation at /proc/tinker/oled\n");
	return 0;
}

static void __exit tinker_oled_exit(void)
{
	pr_info("TinkerOS: OLED wear compensation removed\n");
}

module_init(tinker_oled_init);
module_exit(tinker_oled_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS OLED burn-in wear compensation");
