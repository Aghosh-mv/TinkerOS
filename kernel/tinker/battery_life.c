// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS battery lifespan manager.
 *
 * Implements the "lifespan doubler" concept as a kernel feature: track a
 * safe charge envelope (trickle-charge lower bound and top-off cap) and
 * expose it via /proc/tinker/battery so the charging policy layer or a
 * small user-space frontend can keep the battery cool and durable.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/power_supply.h>

#include "tinker_core.h"

#define BATTERY_BUFSZ	64
#define CHARGE_MIN_DEFAULT	20	/* % */
#define CHARGE_MAX_DEFAULT	80	/* % */

static DEFINE_MUTEX(battery_lock);
static int charge_min = CHARGE_MIN_DEFAULT;
static int charge_max = CHARGE_MAX_DEFAULT;
static bool lifespan_mode;

/* Query used by the power_supply layer: is lifespan charging on? */
bool tinker_battery_lifespan(void)
{
	bool on;

	mutex_lock(&battery_lock);
	on = lifespan_mode;
	mutex_unlock(&battery_lock);
	return on;
}
EXPORT_SYMBOL_GPL(tinker_battery_lifespan);

/* Charge envelope getters (percent). */
void tinker_battery_envelope(int *lo, int *hi)
{
	mutex_lock(&battery_lock);
	if (lo)
		*lo = charge_min;
	if (hi)
		*hi = charge_max;
	mutex_unlock(&battery_lock);
}
EXPORT_SYMBOL_GPL(tinker_battery_envelope);

static int battery_show(struct seq_file *m, void *v)
{
	mutex_lock(&battery_lock);
	seq_printf(m, "mode:       %s\n", lifespan_mode ? "lifespan" : "normal");
	seq_printf(m, "charge_min: %d%%\n", charge_min);
	seq_printf(m, "charge_max: %d%%\n", charge_max);
	seq_printf(m, "policy:     trickle below min, top-off only near max\n");
	mutex_unlock(&battery_lock);
	return 0;
}

static ssize_t battery_write(struct file *file, const char __user *ubuf,
			     size_t len, loff_t *ppos)
{
	char buf[BATTERY_BUFSZ];
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

	mutex_lock(&battery_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		lifespan_mode = true;
	} else if (!strcmp(cmd, "off")) {
		lifespan_mode = false;
	} else if (!strcmp(cmd, "min") && arg) {
		val = simple_strtol(arg, NULL, 10);
		charge_min = clamp(val, 0, 100);
	} else if (!strcmp(cmd, "max") && arg) {
		val = simple_strtol(arg, NULL, 10);
		charge_max = clamp(val, 0, 100);
		if (charge_max < charge_min)
			charge_max = charge_min;
	} else {
		mutex_unlock(&battery_lock);
		return -EINVAL;
	}
	mutex_unlock(&battery_lock);
	return len;
}

static int battery_open(struct inode *inode, struct file *file)
{
	return single_open(file, battery_show, NULL);
}

static const struct proc_ops battery_fops = {
	.proc_open	= battery_open,
	.proc_read	= seq_read,
	.proc_write	= battery_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_battery_init(void)
{
	if (tinker_proc_root)
		proc_create("battery", 0644, tinker_proc_root,
			    &battery_fops);

	pr_info("TinkerOS: battery lifespan manager at /proc/tinker/battery\n");
	return 0;
}

static void __exit tinker_battery_exit(void)
{
	pr_info("TinkerOS: battery lifespan manager removed\n");
}

module_init(tinker_battery_init);
module_exit(tinker_battery_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS battery lifespan manager");
