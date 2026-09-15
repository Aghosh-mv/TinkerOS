// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Update Monitor — kernel-level update state and scheduling
 * Provides /proc/tinker/update interface
 * Tracks update status, rollback state, kernel versions, auto-update scheduling
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include <linux/timer.h>
#include <linux/jiffies.h>

#define UPDATE_STATE_IDLE      0
#define UPDATE_STATE_RUNNING   1
#define UPDATE_STATE_COMPLETE  2
#define UPDATE_STATE_FAILED    3
#define UPDATE_STATE_ROLLBACK  4

#define KERNEL_MAX_ENTRIES 32
#define KERNEL_NAME_MAX    128

struct kernel_entry {
	char name[KERNEL_NAME_MAX];
	int active;
	ktime_t installed;
};

struct update_state {
	int current_state;
	int auto_update_enabled;
	int update_count;
	int rollback_count;
	int failures;
	ktime_t last_update;
	ktime_t next_scheduled;
	struct kernel_entry kernels[KERNEL_MAX_ENTRIES];
	int kernel_count;
	char last_error[256];
	struct mutex lock;
	struct timer_list schedule_timer;
};

static struct proc_dir_entry *update_proc_entry;
static struct update_state *upd_state;

static void update_schedule_cb(struct timer_list *t)
{
	struct update_state *state = from_timer(state, t, schedule_timer);

	if (state && state->auto_update_enabled) {
		mutex_lock(&state->lock);
		state->current_state = UPDATE_STATE_RUNNING;
		state->last_update = ktime_get_real();
		mutex_unlock(&state->lock);
		pr_info("KorrinOS: scheduled update triggered\n");
	}
}

static int update_show(struct seq_file *m, void *v)
{
	const char *state_str;
	int i;

	if (!upd_state)
		return 0;

	switch (upd_state->current_state) {
	case UPDATE_STATE_IDLE:      state_str = "idle"; break;
	case UPDATE_STATE_RUNNING:   state_str = "running"; break;
	case UPDATE_STATE_COMPLETE:  state_str = "complete"; break;
	case UPDATE_STATE_FAILED:    state_str = "failed"; break;
	case UPDATE_STATE_ROLLBACK:  state_str = "rollback"; break;
	default:                     state_str = "unknown"; break;
	}

	seq_printf(m, "=== KorrinOS Update Monitor ===\n\n");
	seq_printf(m, "State:            %s\n", state_str);
	seq_printf(m, "Auto-update:      %s\n", upd_state->auto_update_enabled ? "enabled" : "disabled");
	seq_printf(m, "Total updates:    %d\n", upd_state->update_count);
	seq_printf(m, "Rollbacks:        %d\n", upd_state->rollback_count);
	seq_printf(m, "Failures:         %d\n", upd_state->failures);
	seq_printf(m, "Running kernel:   %s\n", "current");
	seq_printf(m, "\nInstalled kernels:\n");

	for (i = 0; i < upd_state->kernel_count; i++) {
		seq_printf(m, "  %s %s\n",
			   upd_state->kernels[i].active ? "[active]" : "        ",
			   upd_state->kernels[i].name);
	}

	if (upd_state->last_error[0])
		seq_printf(m, "\nLast error: %s\n", upd_state->last_error);

	return 0;
}

static int update_open(struct inode *inode, struct file *file)
{
	return single_open(file, update_show, NULL);
}

static ssize_t update_write(struct file *file, const char __user *buf,
			    size_t count, loff_t *ppos)
{
	char kbuf[256];
	char cmd[32];
	int ret;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	ret = sscanf(kbuf, "%31s", cmd);
	if (ret < 1)
		return -EINVAL;

	mutex_lock(&upd_state->lock);

	if (strcmp(cmd, "start") == 0) {
		upd_state->current_state = UPDATE_STATE_RUNNING;
		upd_state->update_count++;
		upd_state->last_update = ktime_get_real();
	} else if (strcmp(cmd, "complete") == 0) {
		upd_state->current_state = UPDATE_STATE_COMPLETE;
	} else if (strcmp(cmd, "fail") == 0) {
		upd_state->current_state = UPDATE_STATE_FAILED;
		upd_state->failures++;
		sscanf(kbuf, "%*s %255[^\n]", upd_state->last_error);
	} else if (strcmp(cmd, "rollback") == 0) {
		upd_state->current_state = UPDATE_STATE_ROLLBACK;
		upd_state->rollback_count++;
	} else if (strcmp(cmd, "idle") == 0) {
		upd_state->current_state = UPDATE_STATE_IDLE;
	} else if (strcmp(cmd, "enable-auto") == 0) {
		upd_state->auto_update_enabled = 1;
	} else if (strcmp(cmd, "disable-auto") == 0) {
		upd_state->auto_update_enabled = 0;
	} else {
		mutex_unlock(&upd_state->lock);
		return -EINVAL;
	}

	mutex_unlock(&upd_state->lock);
	return count;
}

static const struct proc_ops update_proc_ops = {
	.proc_open    = update_open,
	.proc_write   = update_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init update_init(void)
{
	upd_state = kzalloc(sizeof(*upd_state), GFP_KERNEL);
	if (!upd_state)
		return -ENOMEM;

	mutex_init(&upd_state->lock);
	upd_state->current_state = UPDATE_STATE_IDLE;
	upd_state->auto_update_enabled = 1;

	timer_setup(&upd_state->schedule_timer, update_schedule_cb, 0);

	update_proc_entry = proc_create("tinker/update", 0644, NULL,
					&update_proc_ops);
	if (!update_proc_entry) {
		kfree(upd_state);
		return -ENOMEM;
	}

	pr_info("KorrinOS: update monitor loaded\n");
	return 0;
}

static void __exit update_exit(void)
{
	del_timer_sync(&upd_state->schedule_timer);
	proc_remove(update_proc_entry);
	kfree(upd_state);
	pr_info("KorrinOS: update monitor unloaded\n");
}

module_init(update_init);
module_exit(update_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel update state monitor");
MODULE_VERSION("1.0");
