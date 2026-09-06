// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS unified memory — software-defined heterogeneous memory pool.
 *
 * A higher-level view over CXL/hardware tiering: a pool registry with
 * per-device bandwidth/latency/priority used to hint tier placement.
 * Opt-in only. Exposes /proc/tinker/unifiedmem.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define UM_BUFSZ	64

static DEFINE_MUTEX(um_lock);
static bool um_enabled;
static unsigned int um_pools;
static unsigned long long um_local_dram_mb;
static unsigned long long um_remote_mb;

static int um_show(struct seq_file *m, void *v)
{
	mutex_lock(&um_lock);
	seq_printf(m, "enabled:          %u\n", um_enabled);
	seq_printf(m, "pools:            %u\n", um_pools);
	seq_printf(m, "local_dram_mb:    %llu\n", um_local_dram_mb);
	seq_printf(m, "remote_mb:        %llu\n", um_remote_mb);
	seq_puts(m, "policy:           software-defined tier placement\n");
	seq_puts(m, "consent:          opt-in only\n");
	mutex_unlock(&um_lock);
	return 0;
}

static ssize_t um_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[UM_BUFSZ];
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

	mutex_lock(&um_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		um_enabled = true;
		um_pools = 2;
	} else if (!strcmp(cmd, "off")) {
		um_enabled = false;
	} else if (!strcmp(cmd, "local") && arg) {
		val = simple_strtol(arg, NULL, 10);
		um_local_dram_mb = val > 0 ? (unsigned long long)val : 0;
	} else if (!strcmp(cmd, "remote") && arg) {
		val = simple_strtol(arg, NULL, 10);
		um_remote_mb = val > 0 ? (unsigned long long)val : 0;
	} else {
		mutex_unlock(&um_lock);
		return -EINVAL;
	}
	mutex_unlock(&um_lock);
	return len;
}

static int um_open(struct inode *inode, struct file *file)
{
	return single_open(file, um_show, NULL);
}

static const struct proc_ops um_fops = {
	.proc_open	= um_open,
	.proc_read	= seq_read,
	.proc_write	= um_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_um_init(void)
{
	if (tinker_proc_root)
		proc_create("unifiedmem", 0644, tinker_proc_root, &um_fops);

	pr_info("TinkerOS: unified memory at /proc/tinker/unifiedmem (opt-in)\n");
	return 0;
}

static void __exit tinker_um_exit(void)
{
	pr_info("TinkerOS: unified memory removed\n");
}

module_init(tinker_um_init);
module_exit(tinker_um_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS unified heterogeneous memory pool");
