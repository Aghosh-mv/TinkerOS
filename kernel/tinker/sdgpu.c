// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS SD-GPU — software-defined GPU control plane.
 *
 * On systems with a real GPU this would map to DRM/compute scheduling.
 * Here it exposes a software-defined GPU policy (compute share, latency
 * mode, vram hint, power cap) as a kernel control plane that a real or
 * virtual GPU backend consumes. No raw hardware register pokes.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "tinker_core.h"

#define SDGPU_BUFSZ	64

static DEFINE_MUTEX(sdgpulock);
static bool sdgpu_enabled;
static unsigned int sdgpu_compute_share = 100;	/* % */
static unsigned int sdgpu_latency_ms = 4;
static unsigned int sdgpu_power_cap_pct = 100;

static int sdgpu_show(struct seq_file *m, void *v)
{
	mutex_lock(&sdgpulock);
	seq_printf(m, "enabled:          %u\n", sdgpu_enabled);
	seq_printf(m, "compute_share_pct:%u\n", sdgpu_compute_share);
	seq_printf(m, "latency_ms:       %u\n", sdgpu_latency_ms);
	seq_printf(m, "power_cap_pct:    %u\n", sdgpu_power_cap_pct);
	seq_puts(m, "backend:          DRM/compute hint plane\n");
	mutex_unlock(&sdgpulock);
	return 0;
}

static ssize_t sdgpu_write(struct file *file, const char __user *ubuf,
			   size_t len, loff_t *ppos)
{
	char buf[SDGPU_BUFSZ];
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

	mutex_lock(&sdgpulock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on"))
		sdgpu_enabled = true;
	else if (!strcmp(cmd, "off"))
		sdgpu_enabled = false;
	else if (!strcmp(cmd, "share") && arg) {
		val = simple_strtol(arg, NULL, 10);
		sdgpu_compute_share = clamp_t(unsigned int, val, 1, 100);
	} else if (!strcmp(cmd, "cap") && arg) {
		val = simple_strtol(arg, NULL, 10);
		sdgpu_power_cap_pct = clamp_t(unsigned int, val, 10, 100);
	} else {
		mutex_unlock(&sdgpulock);
		return -EINVAL;
	}
	mutex_unlock(&sdgpulock);
	return len;
}

static int sdgpu_open(struct inode *inode, struct file *file)
{
	return single_open(file, sdgpu_show, NULL);
}

static const struct proc_ops sdgpu_fops = {
	.proc_open	= sdgpu_open,
	.proc_read	= seq_read,
	.proc_write	= sdgpu_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_sdgpu_init(void)
{
	if (tinker_proc_root)
		proc_create("sdgpu", 0644, tinker_proc_root, &sdgpu_fops);

	pr_info("TinkerOS: SD-GPU control plane at /proc/tinker/sdgpu\n");
	return 0;
}

static void __exit tinker_sdgpu_exit(void)
{
	pr_info("TinkerOS: SD-GPU control plane removed\n");
}

module_init(tinker_sdgpu_init);
module_exit(tinker_sdgpu_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS software-defined GPU control plane");
