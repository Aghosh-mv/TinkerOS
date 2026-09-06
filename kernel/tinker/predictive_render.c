// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS predictive render — ahead-of-time render hint.
 *
 * Exposes a render-prewarm profile (frame target, quality, predictive
 * frames) and hit/miss feedback so a renderer can pre-render frames the
 * OS predicts will be needed, reducing stutter.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define PR_BUFSZ	64

static DEFINE_MUTEX(pr_lock);
static bool pr_enabled;
static unsigned int pr_prewarm_frames = 3;
static unsigned int pr_target_fps = 60;
static unsigned long long pr_hits;
static unsigned long long pr_misses;

static int pr_show(struct seq_file *m, void *v)
{
	mutex_lock(&pr_lock);
	seq_printf(m, "enabled:         %u\n", pr_enabled);
	seq_printf(m, "prewarm_frames:  %u\n", pr_prewarm_frames);
	seq_printf(m, "target_fps:      %u\n", pr_target_fps);
	seq_printf(m, "hits:            %llu\n", pr_hits);
	seq_printf(m, "misses:          %llu\n", pr_misses);
	seq_puts(m, "policy:          predictive frame pre-render\n");
	mutex_unlock(&pr_lock);
	return 0;
}

static ssize_t pr_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[PR_BUFSZ];
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

	mutex_lock(&pr_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on"))
		pr_enabled = true;
	else if (!strcmp(cmd, "off"))
		pr_enabled = false;
	else if (!strcmp(cmd, "hit"))
		pr_hits++;
	else if (!strcmp(cmd, "miss"))
		pr_misses++;
	else if (!strcmp(cmd, "prewarm") && arg) {
		val = simple_strtol(arg, NULL, 10);
		pr_prewarm_frames = clamp_t(unsigned int, val, 1, 16);
	} else {
		mutex_unlock(&pr_lock);
		return -EINVAL;
	}
	mutex_unlock(&pr_lock);
	return len;
}

static int pr_open(struct inode *inode, struct file *file)
{
	return single_open(file, pr_show, NULL);
}

static const struct proc_ops pr_fops = {
	.proc_open	= pr_open,
	.proc_read	= seq_read,
	.proc_write	= pr_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_pr_init(void)
{
	if (tinker_proc_root)
		proc_create("predictrender", 0644, tinker_proc_root, &pr_fops);

	pr_info("TinkerOS: predictive render at /proc/tinker/predictrender\n");
	return 0;
}

static void __exit tinker_pr_exit(void)
{
	pr_info("TinkerOS: predictive render removed\n");
}

module_init(tinker_pr_init);
module_exit(tinker_pr_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS predictive rendering");
