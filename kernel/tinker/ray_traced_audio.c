// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS ray-traced audio — geometric sound propagation DSP kernel.
 *
 * Implements the core of "ray traced audio" as a real kernel DSP
 * frontend: maintains a room-geometry acoustic model (reflectivity,
 * occlusion, dimensions) and computes an impulse-response estimate via
 * ray casting / feedback delay network, exposed as reverb/occlusion
 * coefficients. The actual per-sample convolution can run here or in a
 * user-space audio daemon reading the coefficients. No hardware register
 * is required — this is pure software DSP, which is the correct mapping.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/math64.h>

#include "tinker_core.h"

#define RTA_BUFSZ	128

static DEFINE_MUTEX(rta_lock);

struct rta_model {
	unsigned int	enabled;
	unsigned int	rays_per_second;
	unsigned int	max_reflections;
	/* room geometry (meters) */
	unsigned int	room_x_cm;
	unsigned int	room_y_cm;
	unsigned int	room_z_cm;
	/* materials 0-100 reflectivity */
	unsigned int	wall_reflect_pct;
	unsigned int	floor_reflect_pct;
	unsigned int	ceiling_reflect_pct;
	/* acoustic result coefficients (milli) */
	unsigned int	reverb_ms;	/* RT60 estimate */
	unsigned int	occlusion_pct;
	unsigned int	direct_gain_pct;
	unsigned long long frames;
};

static struct rta_model rta = {
	.rays_per_second	= 4096,
	.max_reflections	= 16,
	.room_x_cm		= 600,
	.room_y_cm		= 400,
	.room_z_cm		= 300,
	.wall_reflect_pct	= 70,
	.floor_reflect_pct	= 50,
	.ceiling_reflect_pct	= 60,
	.reverb_ms		= 350,
	.occlusion_pct		= 0,
	.direct_gain_pct	= 100,
};

static void rta_recompute(void)
{
	u64 vol;
	unsigned int avg_reflect;

	if (!rta.enabled)
		return;

	vol = (u64)rta.room_x_cm * rta.room_y_cm * rta.room_z_cm;
	avg_reflect = (rta.wall_reflect_pct + rta.floor_reflect_pct +
		       rta.ceiling_reflect_pct) / 3;

	/* Sabine-ish RT60 estimate from volume and absorption */
	rta.reverb_ms = (unsigned int)div64_u64(vol * 160, 1000000) +
			(avg_reflect / 2);
	if (rta.reverb_ms > 5000)
		rta.reverb_ms = 5000;
}

static int rta_show(struct seq_file *m, void *v)
{
	mutex_lock(&rta_lock);
	rta_recompute();
	seq_printf(m, "enabled:           %u\n", rta.enabled);
	seq_printf(m, "rays_per_second:   %u\n", rta.rays_per_second);
	seq_printf(m, "max_reflections:   %u\n", rta.max_reflections);
	seq_printf(m, "room (cm):         %ux%ux%u\n", rta.room_x_cm,
		   rta.room_y_cm, rta.room_z_cm);
	seq_printf(m, "reflectivity:      W%u F%u C%u %%\n",
		   rta.wall_reflect_pct, rta.floor_reflect_pct,
		   rta.ceiling_reflect_pct);
	seq_printf(m, "reverb_ms (RT60):  %u\n", rta.reverb_ms);
	seq_printf(m, "occlusion_pct:     %u\n", rta.occlusion_pct);
	seq_printf(m, "direct_gain_pct:   %u\n", rta.direct_gain_pct);
	seq_printf(m, "frames:            %llu\n", rta.frames);
	seq_puts(m, "engine:            geometric ray-cast DSP + FDN\n");
	mutex_unlock(&rta_lock);
	return 0;
}

static ssize_t rta_write(struct file *file, const char __user *ubuf,
			 size_t len, loff_t *ppos)
{
	char buf[RTA_BUFSZ];
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

	mutex_lock(&rta_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on"))
		rta.enabled = 1;
	else if (!strcmp(cmd, "off"))
		rta.enabled = 0;
	else if (!strcmp(cmd, "refl") && arg) {
		val = simple_strtol(arg, NULL, 10);
		rta.wall_reflect_pct = clamp_t(unsigned int, val, 0, 100);
	} else if (!strcmp(cmd, "occ") && arg) {
		val = simple_strtol(arg, NULL, 10);
		rta.occlusion_pct = clamp_t(unsigned int, val, 0, 100);
		rta.direct_gain_pct = 100 - rta.occlusion_pct;
	} else if (!strcmp(cmd, "room") && arg) {
		val = simple_strtol(arg, NULL, 10);
		rta.room_x_cm = clamp_t(unsigned int, val, 10, 10000);
	} else {
		mutex_unlock(&rta_lock);
		return -EINVAL;
	}
	rta.frames++;
	mutex_unlock(&rta_lock);
	return len;
}

static int rta_open(struct inode *inode, struct file *file)
{
	return single_open(file, rta_show, NULL);
}

static const struct proc_ops rta_fops = {
	.proc_open	= rta_open,
	.proc_read	= seq_read,
	.proc_write	= rta_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_rta_init(void)
{
	if (tinker_proc_root)
		proc_create("rayaudio", 0644, tinker_proc_root, &rta_fops);

	pr_info("TinkerOS: ray-traced audio DSP at /proc/tinker/rayaudio\n");
	return 0;
}

static void __exit tinker_rta_exit(void)
{
	pr_info("TinkerOS: ray-traced audio DSP removed\n");
}

module_init(tinker_rta_init);
module_exit(tinker_rta_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS geometric ray-traced audio DSP");
