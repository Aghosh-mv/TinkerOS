// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS coil-whine killer — PWM frequency shifter hint.
 *
 * Exposes a PWM switching-frequency hint for power-delivery VRMs so it
 * can be shifted out of the human hearing band (or spread-spectrum).
 * The actual VRM register is model-specific; this module is the safe
 * capability-probing frontend with an explicit-consent gate (default
 * OFF), matching the user's requirement that hardware effects never run
 * without an on-screen popup / explicit toggle.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/jiffies.h>
#include <linux/timer.h>

#include "tinker_core.h"

#define CW_BUFSZ	64

static DEFINE_MUTEX(cw_lock);
static unsigned int cw_freq_khz = 300;
static unsigned int cw_base_freq_khz = 300;
static bool cw_enabled;
static bool cw_spread_spectrum;
static unsigned int cw_spread_khz = 50;
static bool cw_popup_shown;
static struct timer_list cw_spread_timer;

static int cw_show(struct seq_file *m, void *v)
{
	mutex_lock(&cw_lock);
	seq_printf(m, "enabled:          %u\n", cw_enabled);
	seq_printf(m, "freq_khz:         %u\n", cw_freq_khz);
	seq_printf(m, "base_freq_khz:    %u\n", cw_base_freq_khz);
	seq_printf(m, "spread_spectrum:  %u\n", cw_spread_spectrum);
	seq_printf(m, "spread_khz:       %u\n", cw_spread_khz);
	seq_printf(m, "popup_shown:      %u\n", cw_popup_shown);
	seq_puts(m, "policy:           shift VRM PWM out of 1-8 kHz band\n");
	seq_puts(m, "consent:          explicit toggle required (default off)\n");
	mutex_unlock(&cw_lock);
	return 0;
}

static ssize_t cw_write(struct file *file, const char __user *ubuf,
			size_t len, loff_t *ppos)
{
	char buf[CW_BUFSZ];
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

	mutex_lock(&cw_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		cw_enabled = true;
		cw_popup_shown = true;
	} else if (!strcmp(cmd, "off")) {
		cw_enabled = false;
		cw_popup_shown = false;
	} else if (!strcmp(cmd, "freq") && arg) {
		val = simple_strtol(arg, NULL, 10);
		cw_freq_khz = clamp(val, 100, 1000);
		cw_base_freq_khz = cw_freq_khz;
	} else if (!strcmp(cmd, "spread") && arg) {
		val = simple_strtol(arg, NULL, 10);
		if (val)
			cw_spread_spectrum = true;
		else
			cw_spread_spectrum = false;
	} else {
		mutex_unlock(&cw_lock);
		return -EINVAL;
	}
	mutex_unlock(&cw_lock);
	return len;
}

static int cw_open(struct inode *inode, struct file *file)
{
	return single_open(file, cw_show, NULL);
}

static const struct proc_ops cw_fops = {
	.proc_open	= cw_open,
	.proc_read	= seq_read,
	.proc_write	= cw_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static void cw_spread_timer_fn(struct timer_list *t)
{
	unsigned int jitter;

	if (!cw_enabled || !cw_spread_spectrum || cw_spread_khz == 0)
		goto resched;

	jitter = get_random_u32() % (2 * cw_spread_khz);
	mutex_lock(&cw_lock);
	cw_freq_khz = cw_base_freq_khz + jitter - cw_spread_khz;
	mutex_unlock(&cw_lock);

resched:
	mod_timer(&cw_spread_timer, jiffies + msecs_to_jiffies(10));
}

static int __init tinker_cw_init(void)
{
	timer_setup(&cw_spread_timer, cw_spread_timer_fn, 0);
	mod_timer(&cw_spread_timer, jiffies + msecs_to_jiffies(10));

	if (tinker_proc_root)
		proc_create("coil_whine", 0644, tinker_proc_root, &cw_fops);

	pr_info("TinkerOS: coil-whine killer (PWM hint) at /proc/tinker/coil_whine\n");
	return 0;
}

static void __exit tinker_cw_exit(void)
{
	timer_delete_sync(&cw_spread_timer);
	pr_info("TinkerOS: coil-whine killer removed\n");
}

module_init(tinker_cw_init);
module_exit(tinker_cw_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS coil-whine PWM frequency shifter");
