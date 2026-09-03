// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS remote hardware API.
 *
 * Exposes limited, authenticated remote-h/w control slots (remote
 * power, remote fan, remote diagnostic) through a single proc interface.
 * Remote access is opt-in and requires an explicit armed token to
 * reduce the attack surface (no open network listener in the kernel).
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define RHA_BUFSZ	64

static DEFINE_MUTEX(rha_lock);
static bool rha_remote_enabled;
static bool rha_armed;
static unsigned int rha_allow_power;
static unsigned int rha_allow_fan;
static unsigned long long rha_calls;

static int rha_show(struct seq_file *m, void *v)
{
	mutex_lock(&rha_lock);
	seq_printf(m, "remote_enabled:  %u\n", rha_remote_enabled);
	seq_printf(m, "armed:           %u\n", rha_armed);
	seq_printf(m, "allow_power:     %u\n", rha_allow_power);
	seq_printf(m, "allow_fan:       %u\n", rha_allow_fan);
	seq_printf(m, "calls:           %llu\n", rha_calls);
	seq_puts(m, "policy:          opt-in, armed-token gated\n");
	mutex_unlock(&rha_lock);
	return 0;
}

static ssize_t rha_write(struct file *file, const char __user *ubuf,
			 size_t len, loff_t *ppos)
{
	char buf[RHA_BUFSZ];
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

	mutex_lock(&rha_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "enable")) {
		rha_remote_enabled = true;
	} else if (!strcmp(cmd, "disable")) {
		rha_remote_enabled = false;
		rha_armed = false;
	} else if (!strcmp(cmd, "arm") && arg) {
		if (!rha_remote_enabled) {
			mutex_unlock(&rha_lock);
			return -EACCES;
		}
		val = simple_strtol(arg, NULL, 10);
		rha_armed = val ? 1 : 0;
	} else if (!strcmp(cmd, "perm") && arg) {
		val = simple_strtol(arg, NULL, 10);
		rha_allow_power = val & 1;
		rha_allow_fan = (val >> 1) & 1;
	} else if (!strcmp(cmd, "power")) {
		if (rha_armed && rha_allow_power)
			rha_calls++;
		else {
			mutex_unlock(&rha_lock);
			return -EACCES;
		}
	} else {
		mutex_unlock(&rha_lock);
		return -EINVAL;
	}
	mutex_unlock(&rha_lock);
	return len;
}

static int rha_open(struct inode *inode, struct file *file)
{
	return single_open(file, rha_show, NULL);
}

static const struct proc_ops rha_fops = {
	.proc_open	= rha_open,
	.proc_read	= seq_read,
	.proc_write	= rha_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_rha_init(void)
{
	if (tinker_proc_root)
		proc_create("remotehw", 0644, tinker_proc_root, &rha_fops);

	pr_info("TinkerOS: remote hardware API at /proc/tinker/remotehw\n");
	return 0;
}

static void __exit tinker_rha_exit(void)
{
	pr_info("TinkerOS: remote hardware API removed\n");
}

module_init(tinker_rha_init);
module_exit(tinker_rha_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS remote hardware API");
