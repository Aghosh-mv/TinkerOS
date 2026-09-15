// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Mobile Companion — kernel-level phone connection state
 * Provides /proc/tinker/mobile interface
 * Tracks ADB connections, WiFi ADB, KDE Connect, notification state
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include <linux/net.h>
#include <linux/in.h>
#include <linux/inet.h>

#define MOBILE_MAX_DEVICES 8
#define MOBILE_NAME_MAX    64
#define MOBILE_IP_MAX      16

enum mobile_conn_type {
	MOBILE_CONN_NONE = 0,
	MOBILE_CONN_USB,
	MOBILE_CONN_WIFI_ADB,
	MOBILE_CONN_KDE_CONNECT,
	MOBILE_CONN_SSH
};

struct mobile_device {
	char name[MOBILE_NAME_MAX];
	char ip[MOBILE_IP_MAX];
	enum mobile_conn_type conn_type;
	int connected;
	int screen_mirror_active;
	int notifications_active;
	int clipboard_sync_active;
	int battery_level;
	char battery_status[16];
	char model[MOBILE_NAME_MAX];
	char android_version[16];
	ktime_t connected_since;
	int notifications_forwarded;
};

struct mobile_state {
	struct mobile_device devices[MOBILE_MAX_DEVICES];
	int device_count;
	int auto_connect;
	int total_connections;
	int total_notifications;
	int total_files_transferred;
	long total_data_bytes;
	struct mutex lock;
};

static struct proc_dir_entry *mobile_proc_entry;
static struct mobile_state *mob_st;

static const char *conn_type_str(enum mobile_conn_type t)
{
	switch (t) {
	case MOBILE_CONN_NONE:         return "none";
	case MOBILE_CONN_USB:          return "usb-adb";
	case MOBILE_CONN_WIFI_ADB:     return "wifi-adb";
	case MOBILE_CONN_KDE_CONNECT:  return "kde-connect";
	case MOBILE_CONN_SSH:          return "ssh";
	default:                       return "unknown";
	}
}

static int mobile_show(struct seq_file *m, void *v)
{
	int i;

	if (!mob_st)
		return 0;

	seq_printf(m, "=== KorrinOS Mobile Companion ===\n\n");
	seq_printf(m, "Auto-connect:       %s\n", mob_st->auto_connect ? "enabled" : "disabled");
	seq_printf(m, "Total connections:  %d\n", mob_st->total_connections);
	seq_printf(m, "Notifications:      %d\n", mob_st->total_notifications);
	seq_printf(m, "Files transferred:  %d\n", mob_st->total_files_transferred);
	seq_printf(m, "Data transferred:   %ld KB\n", mob_st->total_data_bytes / 1024);
	seq_printf(m, "Devices:            %d\n\n", mob_st->device_count);

	for (i = 0; i < mob_st->device_count; i++) {
		struct mobile_device *d = &mob_st->devices[i];

		seq_printf(m, "  %-20s [%s] %s\n",
			   d->name,
			   d->connected ? "connected" : "disconnected",
			   conn_type_str(d->conn_type));

		if (d->connected) {
			seq_printf(m, "    Model:    %s\n", d->model);
			seq_printf(m, "    Android:  %s\n", d->android_version);
			seq_printf(m, "    Battery:  %d%% (%s)\n",
				   d->battery_level, d->battery_status);
			seq_printf(m, "    Mirror:   %s\n",
				   d->screen_mirror_active ? "active" : "inactive");
			seq_printf(m, "    Notify:   %s (%d forwarded)\n",
				   d->notifications_active ? "active" : "inactive",
				   d->notifications_forwarded);
		}
	}

	return 0;
}

static int mobile_open(struct inode *inode, struct file *file)
{
	return single_open(file, mobile_show, NULL);
}

static ssize_t mobile_write(struct file *file, const char __user *buf,
			    size_t count, loff_t *ppos)
{
	char kbuf[256];
	char cmd[32], dev_name[MOBILE_NAME_MAX];
	int ret, i;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&mob_st->lock);

	ret = sscanf(kbuf, "%31s %63s", cmd, dev_name);
	if (ret < 1) {
		mutex_unlock(&mob_st->lock);
		return -EINVAL;
	}

	if (strcmp(cmd, "connect") == 0 && ret >= 2) {
		struct mobile_device *dev = NULL;
		for (i = 0; i < mob_st->device_count; i++) {
			if (strcmp(mob_st->devices[i].name, dev_name) == 0) {
				dev = &mob_st->devices[i];
				break;
			}
		}
		if (!dev && mob_st->device_count < MOBILE_MAX_DEVICES) {
			dev = &mob_st->devices[mob_st->device_count++];
			strscpy(dev->name, dev_name, MOBILE_NAME_MAX);
		}
		if (dev) {
			dev->connected = 1;
			dev->conn_type = MOBILE_CONN_USB;
			dev->connected_since = ktime_get_real();
			mob_st->total_connections++;
		}
	} else if (strcmp(cmd, "disconnect") == 0 && ret >= 2) {
		for (i = 0; i < mob_st->device_count; i++) {
			if (strcmp(mob_st->devices[i].name, dev_name) == 0) {
				mob_st->devices[i].connected = 0;
				mob_st->devices[i].conn_type = MOBILE_CONN_NONE;
				break;
			}
		}
	} else if (strcmp(cmd, "notify") == 0) {
		mob_st->total_notifications++;
	} else if (strcmp(cmd, "file") == 0) {
		long bytes;
		sscanf(kbuf, "%*s %*s %ld", &bytes);
		mob_st->total_files_transferred++;
		mob_st->total_data_bytes += bytes;
	} else if (strcmp(cmd, "mirror-start") == 0 && ret >= 2) {
		for (i = 0; i < mob_st->device_count; i++) {
			if (strcmp(mob_st->devices[i].name, dev_name) == 0) {
				mob_st->devices[i].screen_mirror_active = 1;
				break;
			}
		}
	} else if (strcmp(cmd, "mirror-stop") == 0 && ret >= 2) {
		for (i = 0; i < mob_st->device_count; i++) {
			if (strcmp(mob_st->devices[i].name, dev_name) == 0) {
				mob_st->devices[i].screen_mirror_active = 0;
				break;
			}
		}
	} else if (strcmp(cmd, "battery") == 0 && ret >= 3) {
		int level;
		char status[16];
		sscanf(kbuf, "%*s %*s %d %15s", &level, status);
		for (i = 0; i < mob_st->device_count; i++) {
			if (strcmp(mob_st->devices[i].name, dev_name) == 0) {
				mob_st->devices[i].battery_level = level;
				strscpy(mob_st->devices[i].battery_status, status, 16);
				break;
			}
		}
	} else if (strcmp(cmd, "enable-auto") == 0) {
		mob_st->auto_connect = 1;
	} else if (strcmp(cmd, "disable-auto") == 0) {
		mob_st->auto_connect = 0;
	} else {
		mutex_unlock(&mob_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&mob_st->lock);
	return count;
}

static const struct proc_ops mobile_proc_ops = {
	.proc_open    = mobile_open,
	.proc_write   = mobile_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init mobile_init(void)
{
	mob_st = kzalloc(sizeof(*mob_st), GFP_KERNEL);
	if (!mob_st)
		return -ENOMEM;

	mutex_init(&mob_st->lock);
	mob_st->auto_connect = 1;

	mobile_proc_entry = proc_create("tinker/mobile", 0644, NULL,
					&mobile_proc_ops);
	if (!mobile_proc_entry) {
		kfree(mob_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: mobile companion loaded\n");
	return 0;
}

static void __exit mobile_exit(void)
{
	proc_remove(mobile_proc_entry);
	kfree(mob_st);
	pr_info("KorrinOS: mobile companion unloaded\n");
}

module_init(mobile_init);
module_exit(mobile_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel mobile companion state tracker");
MODULE_VERSION("1.0");
