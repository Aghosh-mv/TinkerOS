// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS App Store — kernel-level app ecosystem state
 * Provides /proc/tinker/apps interface
 * Tracks installed apps, reviews, sync state, package operations
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>

#define APPS_MAX_INSTALLED 256
#define APPS_NAME_MAX      64
#define APPS_VER_MAX       32

struct installed_app {
	char name[APPS_NAME_MAX];
	char version[APPS_VER_MAX];
	ktime_t installed;
	int auto_update;
};

struct app_state {
	struct installed_app apps[APPS_MAX_INSTALLED];
	int app_count;
	int total_installed;
	int total_removed;
	int total_updates;
	int total_reviews;
	int repo_synced;
	int repos_count;
	ktime_t last_sync;
	struct mutex lock;
};

static struct proc_dir_entry *apps_proc_entry;
static struct app_state *apps_st;

static int apps_show(struct seq_file *m, void *v)
{
	int i;

	if (!apps_st)
		return 0;

	seq_printf(m, "=== KorrinOS App Store ===\n\n");
	seq_printf(m, "Total installed:  %d\n", apps_st->total_installed);
	seq_printf(m, "Total removed:    %d\n", apps_st->total_removed);
	seq_printf(m, "Total updates:    %d\n", apps_st->total_updates);
	seq_printf(m, "Total reviews:    %d\n", apps_st->total_reviews);
	seq_printf(m, "Repos synced:     %d\n", apps_st->repo_synced);
	seq_printf(m, "\nInstalled apps:\n");

	for (i = 0; i < apps_st->app_count; i++) {
		seq_printf(m, "  %-25s v%-12s %s\n",
			   apps_st->apps[i].name,
			   apps_st->apps[i].version,
			   apps_st->apps[i].auto_update ? "[auto-update]" : "");
	}

	return 0;
}

static int apps_open(struct inode *inode, struct file *file)
{
	return single_open(file, apps_show, NULL);
}

static ssize_t apps_write(struct file *file, const char __user *buf,
			  size_t count, loff_t *ppos)
{
	char kbuf[256];
	char cmd[32], name[APPS_NAME_MAX], version[APPS_VER_MAX];
	int ret, i;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&apps_st->lock);

	ret = sscanf(kbuf, "%31s %63s %31s", cmd, name, version);

	if (strcmp(cmd, "install") == 0 && ret >= 3) {
		struct installed_app *app = NULL;
		for (i = 0; i < apps_st->app_count; i++) {
			if (strcmp(apps_st->apps[i].name, name) == 0) {
				app = &apps_st->apps[i];
				break;
			}
		}
		if (!app && apps_st->app_count < APPS_MAX_INSTALLED) {
			app = &apps_st->apps[apps_st->app_count++];
			strscpy(app->name, name, APPS_NAME_MAX);
		}
		if (app) {
			strscpy(app->version, version, APPS_VER_MAX);
			app->installed = ktime_get_real();
		}
		apps_st->total_installed++;
	} else if (strcmp(cmd, "remove") == 0 && ret >= 2) {
		for (i = 0; i < apps_st->app_count; i++) {
			if (strcmp(apps_st->apps[i].name, name) == 0) {
				memmove(&apps_st->apps[i], &apps_st->apps[i + 1],
					(apps_st->app_count - i - 1) * sizeof(apps_st->apps[0]));
				apps_st->app_count--;
				break;
			}
		}
		apps_st->total_removed++;
	} else if (strcmp(cmd, "update") == 0 && ret >= 3) {
		for (i = 0; i < apps_st->app_count; i++) {
			if (strcmp(apps_st->apps[i].name, name) == 0) {
				strscpy(apps_st->apps[i].version, version, APPS_VER_MAX);
				break;
			}
		}
		apps_st->total_updates++;
	} else if (strcmp(cmd, "review") == 0) {
		apps_st->total_reviews++;
	} else if (strcmp(cmd, "sync") == 0) {
		apps_st->repo_synced++;
		apps_st->last_sync = ktime_get_real();
	} else {
		mutex_unlock(&apps_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&apps_st->lock);
	return count;
}

static const struct proc_ops apps_proc_ops = {
	.proc_open    = apps_open,
	.proc_write   = apps_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init apps_init(void)
{
	apps_st = kzalloc(sizeof(*apps_st), GFP_KERNEL);
	if (!apps_st)
		return -ENOMEM;

	mutex_init(&apps_st->lock);

	apps_proc_entry = proc_create("tinker/apps", 0644, NULL,
				      &apps_proc_ops);
	if (!apps_proc_entry) {
		kfree(apps_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: app store state loaded\n");
	return 0;
}

static void __exit apps_exit(void)
{
	proc_remove(apps_proc_entry);
	kfree(apps_st);
	pr_info("KorrinOS: app store state unloaded\n");
}

module_init(apps_init);
module_exit(apps_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel app ecosystem state");
MODULE_VERSION("1.0");
