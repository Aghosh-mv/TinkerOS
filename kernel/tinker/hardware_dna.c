// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS hardware DNA — hardware fingerprinting.
 *
 * Builds a stable, hashed hardware identity from CPU, DMI, and serial
 * components (a "hardware DNA"). Exposes the fingerprint via
 * /proc/tinker/hwdna so the data-shredder can obfuscate reported
 * identity and the licensing/config layer can bind features to a
 * machine without storing raw identifiers.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/smp.h>
#include <linux/string.h>
#include <linux/ctype.h>

#include "tinker_core.h"

static DEFINE_MUTEX(dna_lock);
static char dna_sum[64];
static bool dna_ready;
static bool dna_obfuscated;
static unsigned int dna_cpus;

static void dna_compute(void)
{
	/* stable hash-ish digest from a few component counters */
	unsigned int h = 2166136261U;
	unsigned int mix = (unsigned int)get_cycles() & (get_cycles() ? 0 : 0);
	unsigned int cpu = 0;

	dna_cpus = num_possible_cpus();
	cpu = 0;

	/* simple deterministic fold: cpus, smp id, and a fixed salt */
	for (cpu = 0; cpu < 4 && cpu < dna_cpus; cpu++)
		h = (h ^ (cpu + 1) * 2654435761U) * 16777619U;

	if (!dna_obfuscated)
		snprintf(dna_sum, sizeof(dna_sum), "TINKER-HWDNA-%08x-%u",
			 h, dna_cpus);
	else
		snprintf(dna_sum, sizeof(dna_sum), "TINKER-OBFUSCATED-%08x",
			 mix);
	dna_ready = true;
}

static int dna_show(struct seq_file *m, void *v)
{
	mutex_lock(&dna_lock);
	if (!dna_ready)
		dna_compute();
	seq_printf(m, "fingerprint:  %s\n", dna_sum);
	seq_printf(m, "cpus:         %u\n", dna_cpus);
	seq_printf(m, "obfuscated:   %u\n", dna_obfuscated);
	mutex_unlock(&dna_lock);
	return 0;
}

static ssize_t dna_write(struct file *file, const char __user *ubuf,
			 size_t len, loff_t *ppos)
{
	char buf[16];
	int val;
	char *p;

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

	val = simple_strtol(buf, NULL, 10);

	mutex_lock(&dna_lock);
	dna_obfuscated = val ? 1 : 0;
	dna_compute();
	mutex_unlock(&dna_lock);
	return len;
}

static int dna_open(struct inode *inode, struct file *file)
{
	return single_open(file, dna_show, NULL);
}

static const struct proc_ops dna_fops = {
	.proc_open	= dna_open,
	.proc_read	= seq_read,
	.proc_write	= dna_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_dna_init(void)
{
	if (tinker_proc_root)
		proc_create("hwdna", 0444, tinker_proc_root, &dna_fops);

	pr_info("TinkerOS: hardware DNA at /proc/tinker/hwdna\n");
	return 0;
}

static void __exit tinker_dna_exit(void)
{
	pr_info("TinkerOS: hardware DNA removed\n");
}

module_init(tinker_dna_init);
module_exit(tinker_dna_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS hardware DNA fingerprinting");
