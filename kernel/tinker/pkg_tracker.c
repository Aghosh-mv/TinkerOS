// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Package Tracker — kernel-level package state tracking
 * Provides /proc/tinker/pkg interface for user-space package manager
 * Tracks install/update/remove events, version changes, integrity hashes
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/stat.h>
#include <linux/mutex.h>
#include <linux/crypto.h>
#include <linux/namei.h>

#define PKG_MAX_ENTRIES 512
#define PKG_NAME_MAX    128
#define PKG_VER_MAX     64
#define PKG_HASH_MAX    64

static struct proc_dir_entry *pkg_proc_entry;

struct pkg_event {
	char name[PKG_NAME_MAX];
	char version[PKG_VER_MAX];
	char hash[PKG_HASH_MAX];
	enum { PKG_INSTALL, PKG_UPDATE, PKG_REMOVE, PKG_VERIFY } action;
	ktime_t timestamp;
	int success;
};

struct pkg_state {
	struct pkg_event events[PKG_MAX_ENTRIES];
	int head;
	int total_installs;
	int total_updates;
	int total_removes;
	int total_verified;
	int integrity_failures;
	ktime_t last_sync;
	struct mutex lock;
};

static struct pkg_state *pkg_state;

static void pkg_record_event(const char *name, const char *version,
			     int action, int success)
{
	struct pkg_event *evt;

	if (!pkg_state)
		return;

	mutex_lock(&pkg_state->lock);
	evt = &pkg_state->events[pkg_state->head];
	strscpy(evt->name, name, PKG_NAME_MAX);
	strscpy(evt->version, version, PKG_VER_MAX);
	evt->action = action;
	evt->timestamp = ktime_get_real();
	evt->success = success;

	pkg_state->head = (pkg_state->head + 1) % PKG_MAX_ENTRIES;

	switch (action) {
	case PKG_INSTALL:
		pkg_state->total_installs++;
		break;
	case PKG_UPDATE:
		pkg_state->total_updates++;
		break;
	case PKG_REMOVE:
		pkg_state->total_removes++;
		break;
	case PKG_VERIFY:
		if (success)
			pkg_state->total_verified++;
		else
			pkg_state->integrity_failures++;
		break;
	}

	pkg_state->last_sync = ktime_get_real();
	mutex_unlock(&pkg_state->lock);
}

static int pkg_show(struct seq_file *m, void *v)
{
	int i, idx;

	if (!pkg_state)
		return 0;

	seq_printf(m, "=== KorrinOS Package Tracker ===\n\n");
	seq_printf(m, "Total installs:    %d\n", pkg_state->total_installs);
	seq_printf(m, "Total updates:     %d\n", pkg_state->total_updates);
	seq_printf(m, "Total removes:     %d\n", pkg_state->total_removes);
	seq_printf(m, "Verified:          %d\n", pkg_state->total_verified);
	seq_printf(m, "Integrity fails:   %d\n", pkg_state->integrity_failures);
	seq_printf(m, "Events buffered:   %d\n", PKG_MAX_ENTRIES);
	seq_printf(m, "\nRecent events:\n");

	for (i = 0; i < min(20, PKG_MAX_ENTRIES); i++) {
		idx = (pkg_state->head - 1 - i + PKG_MAX_ENTRIES) % PKG_MAX_ENTRIES;
		if (pkg_state->events[idx].name[0] == '\0')
			continue;

		const char *action_str;
		switch (pkg_state->events[idx].action) {
		case PKG_INSTALL: action_str = "INSTALL"; break;
		case PKG_UPDATE:  action_str = "UPDATE";  break;
		case PKG_REMOVE:  action_str = "REMOVE";  break;
		case PKG_VERIFY:  action_str = "VERIFY";  break;
		default:          action_str = "UNKNOWN"; break;
		}

		seq_printf(m, "  [%s] %-12s %-20s %s\n",
			   pkg_state->events[idx].success ? "OK" : "FAIL",
			   action_str,
			   pkg_state->events[idx].name,
			   pkg_state->events[idx].version);
	}

	return 0;
}

static int pkg_open(struct inode *inode, struct file *file)
{
	return single_open(file, pkg_show, NULL);
}

static const struct proc_ops pkg_proc_ops = {
	.proc_open    = pkg_open,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

/* User-space interface: write actions to /proc/tinker/pkg */
static ssize_t pkg_write(struct file *file, const char __user *buf,
			 size_t count, loff_t *ppos)
{
	char kbuf[256];
	char action[16], name[PKG_NAME_MAX], version[PKG_VER_MAX];
	int ret, action_val, success;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	ret = sscanf(kbuf, "%15s %127s %63s %d",
		     action, name, version, &success);
	if (ret < 3)
		return -EINVAL;

	if (strcmp(action, "install") == 0)
		action_val = PKG_INSTALL;
	else if (strcmp(action, "update") == 0)
		action_val = PKG_UPDATE;
	else if (strcmp(action, "remove") == 0)
		action_val = PKG_REMOVE;
	else if (strcmp(action, "verify") == 0)
		action_val = PKG_VERIFY;
	else
		return -EINVAL;

	if (ret < 4)
		success = 1;

	pkg_record_event(name, version, action_val, success);

	return count;
}

static const struct proc_ops pkg_proc_write_ops = {
	.proc_open    = pkg_open,
	.proc_write   = pkg_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init pkg_init(void)
{
	pkg_state = kzalloc(sizeof(*pkg_state), GFP_KERNEL);
	if (!pkg_state)
		return -ENOMEM;

	mutex_init(&pkg_state->lock);
	pkg_state->head = 0;

	pkg_proc_entry = proc_create("tinker/pkg", 0644, NULL,
				     &pkg_proc_write_ops);
	if (!pkg_proc_entry) {
		kfree(pkg_state);
		return -ENOMEM;
	}

	pr_info("KorrinOS: package tracker loaded\n");
	return 0;
}

static void __exit pkg_exit(void)
{
	proc_remove(pkg_proc_entry);
	kfree(pkg_state);
	pr_info("KorrinOS: package tracker unloaded\n");
}

module_init(pkg_init);
module_exit(pkg_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel package state tracker");
MODULE_VERSION("1.0");
