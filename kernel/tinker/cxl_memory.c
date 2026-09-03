// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS unified memory over CXL.
 *
 * Exposes a memory-pool registry (local DRAM, GPU VRAM, CXL expander,
 * networked memory) with explicit opt-in only. On systems without CXL,
 * this is a capability-probing interface that records pool composition
 * and desired tiering. Provides visibility into memory tiering intent
 * without defaulting anything on, per the user's requirement.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define CXL_BUFSZ	64

#define POOL_DRAM	0
#define POOL_VRAM	1
#define POOL_CXL	2
#define POOL_NET	3

static DEFINE_MUTEX(cxl_lock);
static bool cxl_enabled;
static unsigned long long cxl_pool_dram_mb;
static unsigned long long cxl_pool_vram_mb;
static unsigned long long cxl_pool_cxl_mb;
static unsigned long long cxl_pool_net_mb;

static int cxl_show(struct seq_file *m, void *v)
{
	mutex_lock(&cxl_lock);
	seq_printf(m, "enabled:     %u\n", cxl_enabled);
	seq_printf(m, "dram_mb:     %llu\n", cxl_pool_dram_mb);
	seq_printf(m, "vram_mb:     %llu\n", cxl_pool_vram_mb);
	seq_printf(m, "cxl_mb:      %llu\n", cxl_pool_cxl_mb);
	seq_printf(m, "net_mb:      %llu\n", cxl_pool_net_mb);
	seq_puts(m, "policy:      opt-in only; nothing enabled by default\n");
	mutex_unlock(&cxl_lock);
	return 0;
}

static ssize_t cxl_write(struct file *file, const char __user *ubuf,
			 size_t len, loff_t *ppos)
{
	char buf[CXL_BUFSZ];
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

	mutex_lock(&cxl_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		cxl_enabled = true;
	} else if (!strcmp(cmd, "off")) {
		cxl_enabled = false;
	} else if (!strcmp(cmd, "pool") && arg) {
		val = simple_strtol(arg, NULL, 10);
		cxl_pool_cxl_mb = val > 0 ? (unsigned long long)val : 0;
	} else {
		mutex_unlock(&cxl_lock);
		return -EINVAL;
	}
	mutex_unlock(&cxl_lock);
	return len;
}

static int cxl_open(struct inode *inode, struct file *file)
{
	return single_open(file, cxl_show, NULL);
}

static const struct proc_ops cxl_fops = {
	.proc_open	= cxl_open,
	.proc_read	= seq_read,
	.proc_write	= cxl_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_cxl_init(void)
{
	if (tinker_proc_root)
		proc_create("cxlmemb", 0644, tinker_proc_root, &cxl_fops);

	pr_info("TinkerOS: unified CXL memory at /proc/tinker/cxlmemb (opt-in)\n");
	return 0;
}

static void __exit tinker_cxl_exit(void)
{
	pr_info("TinkerOS: unified CXL memory removed\n");
}

module_init(tinker_cxl_init);
module_exit(tinker_cxl_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS unified memory over CXL");
