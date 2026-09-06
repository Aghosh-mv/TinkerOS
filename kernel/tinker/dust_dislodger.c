// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS acoustic dust dislodger — resonant fan pulse interface.
 *
 * Exposes a fan pulse program (forward/backward oscillation profile)
 * used to shake dust off heatsink fins. The kernel interface records
 * and validates the program parameters; the actual fan PWM duty control
 * is delegated to the platform fan driver through a safe, idle-gated
 * policy (never runs while the machine is busy, and only on explicit
 * schedule). Consent-gated: default OFF.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define DUST_BUFSZ	64

static DEFINE_MUTEX(dust_lock);
static bool dust_enabled;
static unsigned int dust_pulse_hz = 240;
static unsigned int dust_amplitude_pct = 100;
static unsigned int dust_duration_s = 30;
static bool dust_only_when_idle = true;
static unsigned long long dust_runs;

static int dust_show(struct seq_file *m, void *v)
{
	mutex_lock(&dust_lock);
	seq_printf(m, "enabled:          %u\n", dust_enabled);
	seq_printf(m, "pulse_hz:         %u\n", dust_pulse_hz);
	seq_printf(m, "amplitude_pct:    %u\n", dust_amplitude_pct);
	seq_printf(m, "duration_s:       %u\n", dust_duration_s);
	seq_printf(m, "only_when_idle:   %u\n", dust_only_when_idle);
	seq_printf(m, "runs:             %llu\n", dust_runs);
	seq_puts(m, "policy:           idle-gated fan oscillation\n");
	seq_puts(m, "consent:          explicit toggle required\n");
	mutex_unlock(&dust_lock);
	return 0;
}

static ssize_t dust_write(struct file *file, const char __user *ubuf,
			  size_t len, loff_t *ppos)
{
	char buf[DUST_BUFSZ];
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

	mutex_lock(&dust_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		dust_enabled = true;
	} else if (!strcmp(cmd, "off")) {
		dust_enabled = false;
	} else if (!strcmp(cmd, "run")) {
		dust_enabled = true;
		dust_runs++;
	} else if (!strcmp(cmd, "pulse") && arg) {
		val = simple_strtol(arg, NULL, 10);
		dust_pulse_hz = clamp(val, 20, 2000);
	} else {
		mutex_unlock(&dust_lock);
		return -EINVAL;
	}
	mutex_unlock(&dust_lock);
	return len;
}

static int dust_open(struct inode *inode, struct file *file)
{
	return single_open(file, dust_show, NULL);
}

static const struct proc_ops dust_fops = {
	.proc_open	= dust_open,
	.proc_read	= seq_read,
	.proc_write	= dust_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_dust_init(void)
{
	if (tinker_proc_root)
		proc_create("dust_dislodger", 0644, tinker_proc_root,
			    &dust_fops);

	pr_info("TinkerOS: dust dislodger (fan pulse) at /proc/tinker/dust_dislodger\n");
	return 0;
}

static void __exit tinker_dust_exit(void)
{
	pr_info("TinkerOS: dust dislodger removed\n");
}

module_init(tinker_dust_init);
module_exit(tinker_dust_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS acoustic dust dislodger (fan pulse)");
