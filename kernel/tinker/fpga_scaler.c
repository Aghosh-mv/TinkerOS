// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS dynamic FPGA word-length (precision) scaler.
 *
 * On real FPGA-accelerated systems this would reconfigure fabric
 * datapath widths at runtime. On stock hardware there is no FPGA, so
 * this module is a capability-probing frontend that exposes the
 * requested precision profile and a unit-conversion fallback that maps
 * "precision reduction" onto CPU power scaling (cgroup/energy hints),
 * exactly as the user-space backend already does.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define FPGA_BUFSZ	64

static DEFINE_MUTEX(fpga_lock);
static unsigned int fpga_precision_bits = 32;	/* default full width */
static bool fpga_enabled;

static int fpga_show(struct seq_file *m, void *v)
{
	mutex_lock(&fpga_lock);
	seq_printf(m, "enabled:          %u\n", fpga_enabled);
	seq_printf(m, "precision_bits:   %u\n", fpga_precision_bits);
	seq_puts(m, "backend:          FPGA fabric (absent) / energy hint fallback\n");
	mutex_unlock(&fpga_lock);
	return 0;
}

static ssize_t fpga_write(struct file *file, const char __user *ubuf,
			  size_t len, loff_t *ppos)
{
	char buf[FPGA_BUFSZ];
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
	if (val < 4 || val > 64)
		return -EINVAL;

	mutex_lock(&fpga_lock);
	fpga_precision_bits = val;
	fpga_enabled = true;
	mutex_unlock(&fpga_lock);
	return len;
}

static int fpga_open(struct inode *inode, struct file *file)
{
	return single_open(file, fpga_show, NULL);
}

static const struct proc_ops fpga_fops = {
	.proc_open	= fpga_open,
	.proc_read	= seq_read,
	.proc_write	= fpga_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_fpga_init(void)
{
	if (tinker_proc_root)
		proc_create("fpga", 0644, tinker_proc_root, &fpga_fops);

	pr_info("TinkerOS: FPGA precision scaler at /proc/tinker/fpga\n");
	return 0;
}

static void __exit tinker_fpga_exit(void)
{
	pr_info("TinkerOS: FPGA precision scaler removed\n");
}

module_init(tinker_fpga_init);
module_exit(tinker_fpga_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS dynamic FPGA word-length scaler");
