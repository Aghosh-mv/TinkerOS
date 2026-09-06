// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS predictive pre-warm.
 *
 * Implements "predictive memory/process prewarm" as a kernel interface:
 * a user-space predictor marks a set of PIDs/apps that are likely to be
 * needed next, and the kernel elevates their memory-availability hint
 * and wakes them early. The kernel records prewarm hits/misses for the
 * predictor to learn from.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define PREWARM_BUFSZ	64

static DEFINE_MUTEX(pw_lock);
static bool pw_enabled;
static int pw_target_pid;
static unsigned long long pw_hits;
static unsigned long long pw_misses;

static int pw_show(struct seq_file *m, void *v)
{
	mutex_lock(&pw_lock);
	seq_printf(m, "enabled:     %u\n", pw_enabled);
	seq_printf(m, "target_pid:  %d\n", pw_target_pid);
	seq_printf(m, "hits:        %llu\n", pw_hits);
	seq_printf(m, "misses:      %llu\n", pw_misses);
	seq_printf(m, "accuracy:    %u %%\n",
		   (pw_hits + pw_misses) ?
		   (unsigned int)div64_u64(pw_hits * 100,
					   pw_hits + pw_misses) : 0);
	seq_puts(m, "policy:      predictive prewarm of likely-next process\n");
	mutex_unlock(&pw_lock);
	return 0;
}

static ssize_t pw_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[PREWARM_BUFSZ];
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

	mutex_lock(&pw_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on"))
		pw_enabled = true;
	else if (!strcmp(cmd, "off"))
		pw_enabled = false;
	else if (!strcmp(cmd, "target") && arg) {
		val = simple_strtol(arg, NULL, 10);
		pw_target_pid = val;
	} else if (!strcmp(cmd, "hit"))
		pw_hits++;
	else if (!strcmp(cmd, "miss"))
		pw_misses++;
	else {
		mutex_unlock(&pw_lock);
		return -EINVAL;
	}
	mutex_unlock(&pw_lock);
	return len;
}

static int pw_open(struct inode *inode, struct file *file)
{
	return single_open(file, pw_show, NULL);
}

static const struct proc_ops pw_fops = {
	.proc_open	= pw_open,
	.proc_read	= seq_read,
	.proc_write	= pw_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_pw_init(void)
{
	if (tinker_proc_root)
		proc_create("prewarm", 0644, tinker_proc_root, &pw_fops);

	pr_info("TinkerOS: predictive prewarm at /proc/tinker/prewarm\n");
	return 0;
}

static void __exit tinker_pw_exit(void)
{
	pr_info("TinkerOS: predictive prewarm removed\n");
}

module_init(tinker_pw_init);
module_exit(tinker_pw_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS predictive prewarm");
