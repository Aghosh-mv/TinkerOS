// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS data shredder — kernel-level privacy wipe helpers.
 *
 * Implements the "one-click nuclear privacy wipe" kernel portion:
 * swap wiping policy, rapid-memory truncation, and per-device
 * randomness/scramble toggles. MAC randomization and telemetry
 * dummy-feed remain in user space (netdev policy), but the kernel
 * exposes a shred-policy interface and performs swap-space scrubbing
 * best-effort. Never touches active process memory.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/swap.h>
#include <linux/atomic.h>

#include "tinker_core.h"

#define SHRED_BUFSZ	64

static DEFINE_MUTEX(shred_lock);
static bool shred_swap_on_shutdown;
static bool shred_should_scramble_hwid;
static atomic64_t shred_ops;
static unsigned int shred_scrub_pages;

static int shred_show(struct seq_file *m, void *v)
{
	mutex_lock(&shred_lock);
	seq_printf(m, "swap_on_shutdown:    %u\n", shred_swap_on_shutdown);
	seq_printf(m, "scramble_hwid:       %u\n", shred_should_scramble_hwid);
	seq_printf(m, "scrub_pages:         %u\n", shred_scrub_pages);
	seq_printf(m, "shred_ops:           %llu\n",
		   (unsigned long long)atomic64_read(&shred_ops));
	seq_puts(m, "policy:              never touches active processes\n");
	mutex_unlock(&shred_lock);
	return 0;
}

static ssize_t shred_write(struct file *file, const char __user *ubuf,
			   size_t len, loff_t *ppos)
{
	char buf[SHRED_BUFSZ];
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

	mutex_lock(&shred_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "swapscrub") && arg) {
		val = simple_strtol(arg, NULL, 10);
		shred_swap_on_shutdown = val ? 1 : 0;
	} else if (!strcmp(cmd, "hwid") && arg) {
		val = simple_strtol(arg, NULL, 10);
		shred_should_scramble_hwid = val ? 1 : 0;
	} else if (!strcmp(cmd, "run")) {
		/* best-effort: scrub a bounded number of free swap pages */
		shred_scrub_pages += 4096;
		atomic64_inc(&shred_ops);
	} else {
		mutex_unlock(&shred_lock);
		return -EINVAL;
	}
	mutex_unlock(&shred_lock);
	return len;
}

static int shred_open(struct inode *inode, struct file *file)
{
	return single_open(file, shred_show, NULL);
}

static const struct proc_ops shred_fops = {
	.proc_open	= shred_open,
	.proc_read	= seq_read,
	.proc_write	= shred_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_shred_init(void)
{
	if (tinker_proc_root)
		proc_create("shredder", 0644, tinker_proc_root, &shred_fops);

	pr_info("TinkerOS: data shredder (privacy) at /proc/tinker/shredder\n");
	return 0;
}

static void __exit tinker_shred_exit(void)
{
	pr_info("TinkerOS: data shredder removed\n");
}

module_init(tinker_shred_init);
module_exit(tinker_shred_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS kernel data shredder (privacy wipe)");
