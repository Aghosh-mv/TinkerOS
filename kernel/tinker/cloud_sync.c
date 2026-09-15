// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Cloud Sync Tracker — kernel-level cloud sync state
 * Provides /proc/tinker/cloud interface
 * Tracks sync status, bandwidth, conflict resolution, provider state
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>

#define CLOUD_MAX_PROVIDERS 8
#define CLOUD_NAME_MAX      64
#define CLOUD_PATH_MAX      256

enum cloud_provider_state {
	CLOUD_DISABLED = 0,
	CLOUD_IDLE,
	CLOUD_SYNCING,
	CLOUD_ERROR,
	CLOUD_RATE_LIMITED
};

struct cloud_provider {
	char name[CLOUD_NAME_MAX];
	enum cloud_provider_state state;
	int enabled;
	long bytes_synced;
	int files_synced;
	int conflicts;
	int errors;
	ktime_t last_sync;
	char last_error[128];
};

struct cloud_state {
	struct cloud_provider providers[CLOUD_MAX_PROVIDERS];
	int provider_count;
	int auto_sync_enabled;
	int total_syncs;
	int total_conflicts;
	int total_errors;
	long total_bandwidth_bytes;
	ktime_t last_full_sync;
	struct mutex lock;
};

static struct proc_dir_entry *cloud_proc_entry;
static struct cloud_state *cloud_st;

static struct cloud_provider *find_or_add_provider(const char *name)
{
	int i;

	for (i = 0; i < cloud_st->provider_count; i++) {
		if (strcmp(cloud_st->providers[i].name, name) == 0)
			return &cloud_st->providers[i];
	}

	if (cloud_st->provider_count >= CLOUD_MAX_PROVIDERS)
		return NULL;

	strscpy(cloud_st->providers[cloud_st->provider_count].name, name,
		CLOUD_NAME_MAX);
	cloud_st->providers[cloud_st->provider_count].state = CLOUD_IDLE;
	cloud_st->provider_count++;

	return &cloud_st->providers[cloud_st->provider_count - 1];
}

static const char *cloud_state_str(enum cloud_provider_state s)
{
	switch (s) {
	case CLOUD_DISABLED:     return "disabled";
	case CLOUD_IDLE:         return "idle";
	case CLOUD_SYNCING:      return "syncing";
	case CLOUD_ERROR:        return "error";
	case CLOUD_RATE_LIMITED: return "rate-limited";
	default:                 return "unknown";
	}
}

static int cloud_show(struct seq_file *m, void *v)
{
	int i;

	if (!cloud_st)
		return 0;

	seq_printf(m, "=== KorrinOS Cloud Sync ===\n\n");
	seq_printf(m, "Auto-sync:       %s\n", cloud_st->auto_sync_enabled ? "enabled" : "disabled");
	seq_printf(m, "Total syncs:     %d\n", cloud_st->total_syncs);
	seq_printf(m, "Total conflicts: %d\n", cloud_st->total_conflicts);
	seq_printf(m, "Total errors:    %d\n", cloud_st->total_errors);
	seq_printf(m, "Providers:       %d\n\n", cloud_st->provider_count);

	for (i = 0; i < cloud_st->provider_count; i++) {
		struct cloud_provider *p = &cloud_st->providers[i];

		seq_printf(m, "  %-15s [%s] synced=%ld files=%d conflicts=%d errors=%d\n",
			   p->name, cloud_state_str(p->state),
			   p->bytes_synced, p->files_synced,
			   p->conflicts, p->errors);

		if (p->last_error[0])
			seq_printf(m, "    last error: %s\n", p->last_error);
	}

	return 0;
}

static int cloud_open(struct inode *inode, struct file *file)
{
	return single_open(file, cloud_show, NULL);
}

static ssize_t cloud_write(struct file *file, const char __user *buf,
			   size_t count, loff_t *ppos)
{
	char kbuf[512];
	char cmd[32], provider[CLOUD_NAME_MAX];
	int ret, state_val;
	long bytes;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&cloud_st->lock);

	ret = sscanf(kbuf, "%31s %63s", cmd, provider);
	if (ret < 1) {
		mutex_unlock(&cloud_st->lock);
		return -EINVAL;
	}

	if (strcmp(cmd, "sync-start") == 0 && ret >= 2) {
		struct cloud_provider *p = find_or_add_provider(provider);
		if (p) {
			p->state = CLOUD_SYNCING;
			p->last_sync = ktime_get_real();
		}
		cloud_st->total_syncs++;
	} else if (strcmp(cmd, "sync-complete") == 0 && ret >= 3) {
		struct cloud_provider *p = find_or_add_provider(provider);
		if (p) {
			p->state = CLOUD_IDLE;
			sscanf(kbuf, "%*s %*s %ld", &bytes);
			p->bytes_synced += bytes;
			p->files_synced++;
		}
	} else if (strcmp(cmd, "sync-error") == 0 && ret >= 2) {
		struct cloud_provider *p = find_or_add_provider(provider);
		if (p) {
			p->state = CLOUD_ERROR;
			p->errors++;
			sscanf(kbuf, "%*s %*s %127[^\n]", p->last_error);
		}
		cloud_st->total_errors++;
	} else if (strcmp(cmd, "conflict") == 0 && ret >= 2) {
		struct cloud_provider *p = find_or_add_provider(provider);
		if (p)
			p->conflicts++;
		cloud_st->total_conflicts++;
	} else if (strcmp(cmd, "enable-auto") == 0) {
		cloud_st->auto_sync_enabled = 1;
	} else if (strcmp(cmd, "disable-auto") == 0) {
		cloud_st->auto_sync_enabled = 0;
	} else if (strcmp(cmd, "reset") == 0) {
		memset(cloud_st->providers, 0, sizeof(cloud_st->providers));
		cloud_st->provider_count = 0;
	} else {
		mutex_unlock(&cloud_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&cloud_st->lock);
	return count;
}

static const struct proc_ops cloud_proc_ops = {
	.proc_open    = cloud_open,
	.proc_write   = cloud_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init cloud_init(void)
{
	cloud_st = kzalloc(sizeof(*cloud_st), GFP_KERNEL);
	if (!cloud_st)
		return -ENOMEM;

	mutex_init(&cloud_st->lock);
	cloud_st->auto_sync_enabled = 1;

	cloud_proc_entry = proc_create("tinker/cloud", 0644, NULL,
				       &cloud_proc_ops);
	if (!cloud_proc_entry) {
		kfree(cloud_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: cloud sync tracker loaded\n");
	return 0;
}

static void __exit cloud_exit(void)
{
	proc_remove(cloud_proc_entry);
	kfree(cloud_st);
	pr_info("KorrinOS: cloud sync tracker unloaded\n");
}

module_init(cloud_init);
module_exit(cloud_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel cloud sync state tracker");
MODULE_VERSION("1.0");
