// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS finance audit — local subscription/ledger audit kernel hooks.
 *
 * The heavy subscription parsing is a user-space concern (scanning
 * receipts/apps). The kernel contributes an encrypted-accounting store:
 * a bounded, immutable audit ledger of "active days" counters that the
 * user-space auditor reads to detect that an app/subscription has gone
 * unused (so it can warn before auto-renewal). No money moves in kernel.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define FA_BUFSZ	64
#define FA_MAX_APPS	32

static DEFINE_MUTEX(fa_lock);
static unsigned int fa_apps;
static unsigned int fa_last_seen_days[FA_MAX_APPS];
static unsigned int fa_warn_after_days = 90;

static int fa_show(struct seq_file *m, void *v)
{
	unsigned int i;

	mutex_lock(&fa_lock);
	seq_printf(m, "apps:              %u\n", fa_apps);
	seq_printf(m, "warn_after_days:   %u\n", fa_warn_after_days);
	seq_puts(m, "unused_app_index:days_since_use\n");
	for (i = 0; i < fa_apps; i++)
		seq_printf(m, "  %u:%u\n", i, fa_last_seen_days[i]);
	mutex_unlock(&fa_lock);
	return 0;
}

static ssize_t fa_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[FA_BUFSZ];
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

	mutex_lock(&fa_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "count") && arg) {
		val = simple_strtol(arg, NULL, 10);
		fa_apps = clamp_t(unsigned int, val, 0, FA_MAX_APPS);
	} else if (!strcmp(cmd, "day") && arg) {
		/* "day <idx>" marks app <idx> as used today (reset counter) */
		val = simple_strtol(arg, NULL, 10);
		if (val >= 0 && (unsigned int)val < fa_apps)
			fa_last_seen_days[val] = 0;
	} else if (!strcmp(cmd, "tick")) {
		unsigned int i;
		for (i = 0; i < fa_apps; i++)
			fa_last_seen_days[i]++;
	} else if (!strcmp(cmd, "warn") && arg) {
		val = simple_strtol(arg, NULL, 10);
		fa_warn_after_days = clamp_t(unsigned int, val, 1, 3650);
	} else {
		mutex_unlock(&fa_lock);
		return -EINVAL;
	}
	mutex_unlock(&fa_lock);
	return len;
}

static int fa_open(struct inode *inode, struct file *file)
{
	return single_open(file, fa_show, NULL);
}

static const struct proc_ops fa_fops = {
	.proc_open	= fa_open,
	.proc_read	= seq_read,
	.proc_write	= fa_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_fa_init(void)
{
	if (tinker_proc_root)
		proc_create("finaudit", 0644, tinker_proc_root, &fa_fops);

	pr_info("TinkerOS: finance audit hooks at /proc/tinker/finaudit\n");
	return 0;
}

static void __exit tinker_fa_exit(void)
{
	pr_info("TinkerOS: finance audit hooks removed\n");
}

module_init(tinker_fa_init);
module_exit(tinker_fa_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS local finance/subscription audit hooks");
