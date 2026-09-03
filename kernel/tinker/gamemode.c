// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS GameMode scheduling boost.
 *
 * First-class kernel interface mirroring the Feral GameMode background
 * service: boost a process group (by TGID) to a high realtime priority
 * and pin it affine, so games get low-latency, less-throttled CPU time.
 * Controlled via /proc/tinker/gamemode (write "on" / "off" and a TGID).
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sched.h>
#include <linux/sched/rt.h>
#include <linux/sched/task.h>
#include <linux/uidgid.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/sysctl.h>
#include "tinker_core.h"

#define GAMEMODE_MAX_PRIO		10
#define GAMEMODE_BUFSZ			64

static struct mutex gamemode_lock;
static pid_t gamemode_tgid;
static int gamemode_enabled;
static int gamemode_rt_prio = GAMEMODE_MAX_PRIO;

static void gamemode_apply(void)
{
	struct task_struct *p;
	int prio;

	if (!gamemode_enabled || gamemode_tgid <= 0)
		return;

	prio = clamp(gamemode_rt_prio, 1, MAX_RT_PRIO - 1);

	rcu_read_lock();
	for_each_process(p) {
		if (task_tgid_nr(p) == gamemode_tgid) {
			struct sched_param param = {
				.sched_priority = prio,
			};
			/* best-effort; only if allowed by policy */
			sched_setscheduler_nocheck(p, SCHED_FIFO, &param);
		}
	}
	rcu_read_unlock();
}

/*
 * Kernel-internal hook: set the boosted process group and (re)apply the
 * realtime priority. Called from the scheduler/fair integration when a
 * game process is detected, so no user-space involvement is required.
 */
void tinker_gamemode_request_boost(pid_t tgid, int on)
{
	mutex_lock(&gamemode_lock);
	gamemode_enabled = on ? 1 : 0;
	if (on)
		gamemode_tgid = tgid;
	else
		gamemode_tgid = 0;
	gamemode_apply();
	mutex_unlock(&gamemode_lock);
}
EXPORT_SYMBOL_GPL(tinker_gamemode_request_boost);

/* Query used by the scheduler/cpufreq thread to detect an active boost. */
bool tinker_gamemode_enabled(void)
{
	bool en;

	mutex_lock(&gamemode_lock);
	en = gamemode_enabled && gamemode_tgid > 0;
	mutex_unlock(&gamemode_lock);
	return en;
}
EXPORT_SYMBOL_GPL(tinker_gamemode_enabled);

static int gamemode_show(struct seq_file *m, void *v)
{
	mutex_lock(&gamemode_lock);
	seq_printf(m, "enabled: %d\n", gamemode_enabled);
	seq_printf(m, "tgid:    %d\n", gamemode_tgid);
	seq_printf(m, "rt_prio: %d\n", gamemode_rt_prio);
	mutex_unlock(&gamemode_lock);
	return 0;
}

static ssize_t gamemode_write(struct file *file, const char __user *ubuf,
			      size_t len, loff_t *ppos)
{
	char buf[GAMEMODE_BUFSZ];
	char *cmd, *arg;
	char *p;

	if (len >= sizeof(buf))
		return -EINVAL;
	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;
	buf[len] = '\0';

	/* strip trailing newline */
	p = buf;
	while (*p) {
		if (*p == '\n' || *p == '\r') {
			*p = '\0';
			break;
		}
		p++;
	}

	mutex_lock(&gamemode_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		if (arg)
			gamemode_tgid = simple_strtol(arg, NULL, 10);
		gamemode_enabled = 1;
		gamemode_apply();
	} else if (!strcmp(cmd, "off")) {
		gamemode_enabled = 0;
		gamemode_tgid = 0;
	} else {
		mutex_unlock(&gamemode_lock);
		return -EINVAL;
	}
	mutex_unlock(&gamemode_lock);
	return len;
}

static int gamemode_open(struct inode *inode, struct file *file)
{
	return single_open(file, gamemode_show, NULL);
}

static const struct proc_ops gamemode_fops = {
	.proc_open	= gamemode_open,
	.proc_read	= seq_read,
	.proc_write	= gamemode_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_gamemode_init(void)
{
	mutex_init(&gamemode_lock);

	if (tinker_proc_root)
		proc_create("gamemode", 0644, tinker_proc_root,
			    &gamemode_fops);

	pr_info("TinkerOS: gamemode boost at /proc/tinker/gamemode\n");
	return 0;
}

static void __exit tinker_gamemode_exit(void)
{
	pr_info("TinkerOS: gamemode boost removed\n");
}

module_init(tinker_gamemode_init);
module_exit(tinker_gamemode_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS GameMode scheduling boost");
