// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Driver Monitor — kernel-level driver state tracking
 * Provides /proc/tinker/drivers interface
 * Tracks GPU driver, WiFi, Bluetooth, fingerprint, driver updates, DKMS
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>

#define DRIVER_MAX 16
#define DRIVER_NAME_MAX 64

enum driver_type {
	DRIVER_GPU = 0,
	DRIVER_WIFI,
	DRIVER_BLUETOOTH,
	DRIVER_FINGERPRINT,
	DRIVER_AUDIO,
	DRIVER_PRINTER,
	DRIVER_OTHER
};

struct driver_info {
	char name[DRIVER_NAME_MAX];
	enum driver_type type;
	int loaded;
	int version_major;
	int version_minor;
	int version_patch;
	char module_name[DRIVER_NAME_MAX];
	ktime_t loaded_since;
	int update_available;
	char update_version[32];
};

struct driver_state {
	struct driver_info drivers[DRIVER_MAX];
	int driver_count;
	int gpu_mode;
	int dkms_modules;
	int pending_updates;
	ktime_t last_scan;
	struct mutex lock;
};

static struct proc_dir_entry *drv_proc_entry;
static struct driver_state *drv_st;

static const char *driver_type_str(enum driver_type t)
{
	switch (t) {
	case DRIVER_GPU:         return "gpu";
	case DRIVER_WIFI:        return "wifi";
	case DRIVER_BLUETOOTH:   return "bluetooth";
	case DRIVER_FINGERPRINT: return "fingerprint";
	case DRIVER_AUDIO:       return "audio";
	case DRIVER_PRINTER:     return "printer";
	default:                 return "other";
	}
}

static const char *gpu_mode_str(int mode)
{
	switch (mode) {
	case 0: return "auto";
	case 1: return "nvidia";
	case 2: return "intel";
	case 3: return "hybrid";
	default: return "unknown";
	}
}

static int drivers_show(struct seq_file *m, void *v)
{
	int i;

	if (!drv_st)
		return 0;

	seq_printf(m, "=== KorrinOS Driver Monitor ===\n\n");
	seq_printf(m, "GPU mode:         %s\n", gpu_mode_str(drv_st->gpu_mode));
	seq_printf(m, "DKMS modules:     %d\n", drv_st->dkms_modules);
	seq_printf(m, "Pending updates:  %d\n", drv_st->pending_updates);
	seq_printf(m, "Tracked drivers:  %d\n\n", drv_st->driver_count);

	for (i = 0; i < drv_st->driver_count; i++) {
		struct driver_info *d = &drv_st->drivers[i];

		seq_printf(m, "  %-20s [%s] v%d.%d.%d module=%s %s\n",
			   d->name,
			   driver_type_str(d->type),
			   d->version_major, d->version_minor, d->version_patch,
			   d->module_name,
			   d->loaded ? "LOADED" : "not loaded");

		if (d->update_available)
			seq_printf(m, "    UPDATE: %s\n", d->update_version);
	}

	return 0;
}

static int drivers_open(struct inode *inode, struct file *file)
{
	return single_open(file, drivers_show, NULL);
}

static ssize_t drivers_write(struct file *file, const char __user *buf,
			     size_t count, loff_t *ppos)
{
	char kbuf[256];
	char cmd[32], name[DRIVER_NAME_MAX];
	int ret, i, type_val;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&drv_st->lock);

	ret = sscanf(kbuf, "%31s %63s", cmd, name);
	if (ret < 1) {
		mutex_unlock(&drv_st->lock);
		return -EINVAL;
	}

	if (strcmp(cmd, "load") == 0 && ret >= 3) {
		struct driver_info *d = NULL;
		sscanf(kbuf, "%*s %*s %d", &type_val);
		for (i = 0; i < drv_st->driver_count; i++) {
			if (strcmp(drv_st->drivers[i].name, name) == 0) {
				d = &drv_st->drivers[i];
				break;
			}
		}
		if (!d && drv_st->driver_count < DRIVER_MAX) {
			d = &drv_st->drivers[drv_st->driver_count++];
			strscpy(d->name, name, DRIVER_NAME_MAX);
			d->type = type_val;
		}
		if (d) {
			d->loaded = 1;
			d->loaded_since = ktime_get_real();
		}
	} else if (strcmp(cmd, "unload") == 0 && ret >= 2) {
		for (i = 0; i < drv_st->driver_count; i++) {
			if (strcmp(drv_st->drivers[i].name, name) == 0) {
				drv_st->drivers[i].loaded = 0;
				break;
			}
		}
	} else if (strcmp(cmd, "gpu-mode") == 0 && ret >= 2) {
		sscanf(kbuf, "%*s %d", &drv_st->gpu_mode);
	} else if (strcmp(cmd, "dkms-add") == 0) {
		drv_st->dkms_modules++;
	} else if (strcmp(cmd, "update-available") == 0 && ret >= 3) {
		for (i = 0; i < drv_st->driver_count; i++) {
			if (strcmp(drv_st->drivers[i].name, name) == 0) {
				drv_st->drivers[i].update_available = 1;
				sscanf(kbuf, "%*s %*s %31s",
				       drv_st->drivers[i].update_version);
				break;
			}
		}
		drv_st->pending_updates++;
	} else {
		mutex_unlock(&drv_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&drv_st->lock);
	return count;
}

static const struct proc_ops drv_proc_ops = {
	.proc_open    = drivers_open,
	.proc_write   = drivers_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init drivers_init(void)
{
	drv_st = kzalloc(sizeof(*drv_st), GFP_KERNEL);
	if (!drv_st)
		return -ENOMEM;

	mutex_init(&drv_st->lock);
	drv_st->gpu_mode = 0; /* auto */

	drv_proc_entry = proc_create("tinker/drivers", 0644, NULL,
				     &drv_proc_ops);
	if (!drv_proc_entry) {
		kfree(drv_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: driver monitor loaded\n");
	return 0;
}

static void __exit drivers_exit(void)
{
	proc_remove(drv_proc_entry);
	kfree(drv_st);
	pr_info("KorrinOS: driver monitor unloaded\n");
}

module_init(drivers_init);
module_exit(drivers_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel driver state monitor");
MODULE_VERSION("1.0");
