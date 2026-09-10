// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS software-defined cache tiering (CAT / MPAM) hint interface.
 *
 * Exposes a cache-partitioning "ways" profile that can be applied to
 * CPU resource-control hardware (Intel CAT, AMD way-partitioning, ARM
 * MPAM) via /proc/tinker/cache. Because most desktops have no way to
 * program CAT, this module acts as a capability-probing interface: it
 * detects whether the hardware reports cache ways, and records the
 * realtime/audio tier preference that a driver backend would enforce.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/cache.h>
#include <linux/percpu.h>

#include "tinker_core.h"

#define CACHE_BUFSZ	64

static DEFINE_MUTEX(cache_lock);
static unsigned int cache_l3_ways;
static unsigned int cache_l3_realtime_ways;
static bool cache_enabled;
static unsigned int cache_max_ways = 16;

/* Kernel parameter: override L3 ways detection (0 = auto-detect) */
static unsigned int cache_l3_ways_override;
module_param(cache_l3_ways_override, uint, 0644);
MODULE_PARM_DESC(cache_l3_ways_override,
		 "Override L3 cache ways (0 = auto-detect via CPUID)");

/*
 * Detect L3 cache ways using CPUID leaf 4 (Deterministic Cache Parameters).
 * Iterates sub-leaves until type=0 (no more caches), looking for L3 (type=3).
 * Returns number of ways on success, 0 if not found.
 */
static unsigned int cache_detect_ways(void)
{
	unsigned int eax, ebx, ecx, edx;
	unsigned int subleaf = 0;
	unsigned int cache_type, cache_level, ways;

	asm volatile("cpuid"
		     : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
		     : "a"(4), "c"(subleaf));

	if ((eax & 0x1f) == 0)
		return 0; /* CPUID leaf 4 not supported */

	for (subleaf = 0; ; subleaf++) {
		asm volatile("cpuid"
			     : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
			     : "a"(4), "c"(subleaf));

		cache_type = eax & 0x1f;
		if (cache_type == 0)
			break; /* no more cache entries */

		cache_level = (eax >> 5) & 0x7;
		if (cache_level == 3 && cache_type == 3) {
			/* L3 unified cache */
			ways = ((ebx >> 22) & 0x3ff) + 1;
			return ways;
		}
	}
	return 0;
}

static int cache_show(struct seq_file *m, void *v)
{
	mutex_lock(&cache_lock);
	seq_printf(m, "enabled:            %u\n", cache_enabled);
	seq_printf(m, "l3_total_ways:      %u\n", cache_max_ways);
	seq_printf(m, "l3_detected_ways:   %u\n", cache_l3_ways);
	seq_printf(m, "realtime_tier_ways: %u\n", cache_l3_realtime_ways);
	seq_printf(m, "policy:             priority-weighted tiering\n");
	seq_puts(m, "backend:            CAT/MPAM (way-partitioning hint)\n");
	mutex_unlock(&cache_lock);
	return 0;
}

static ssize_t cache_write(struct file *file, const char __user *ubuf,
			   size_t len, loff_t *ppos)
{
	char buf[CACHE_BUFSZ];
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

	mutex_lock(&cache_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		cache_enabled = true;
	} else if (!strcmp(cmd, "off")) {
		cache_enabled = false;
	} else if (!strcmp(cmd, "ways") && arg) {
		val = simple_strtol(arg, NULL, 10);
		cache_l3_realtime_ways = clamp_t(unsigned int, val, 1,
						cache_max_ways ? cache_max_ways : 16U);
	} else {
		mutex_unlock(&cache_lock);
		return -EINVAL;
	}
	mutex_unlock(&cache_lock);
	return len;
}

static int cache_open(struct inode *inode, struct file *file)
{
	return single_open(file, cache_show, NULL);
}

static const struct proc_ops cache_fops = {
	.proc_open	= cache_open,
	.proc_read	= seq_read,
	.proc_write	= cache_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_cache_init(void)
{
	unsigned int detected;

	if (cache_l3_ways_override) {
		cache_l3_ways = cache_l3_ways_override;
		cache_max_ways = cache_l3_ways_override;
		pr_info("TinkerOS: cache tiering using override %u ways\n",
			cache_l3_ways);
	} else {
		detected = cache_detect_ways();
		if (detected) {
			cache_l3_ways = detected;
			cache_max_ways = detected;
			pr_info("TinkerOS: cache tiering detected %u L3 ways via CPUID\n",
				detected);
		} else {
			cache_l3_ways = cache_max_ways;
			pr_info("TinkerOS: cache tiering using default %u ways (CPUID unavailable)\n",
				cache_max_ways);
		}
	}
	cache_l3_realtime_ways = 4;

	if (tinker_proc_root)
		proc_create("cache", 0644, tinker_proc_root, &cache_fops);

	pr_info("TinkerOS: cache tiering (CAT/MPAM) at /proc/tinker/cache\n");
	return 0;
}

static void __exit tinker_cache_exit(void)
{
	pr_info("TinkerOS: cache tiering removed\n");
}

module_init(tinker_cache_init);
module_exit(tinker_cache_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS software-defined cache tiering hint");
