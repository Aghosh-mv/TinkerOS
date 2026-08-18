// SPDX-License-Identifier: GPL-2.0
/*
 * Terminal Typo Corrector - Linux Kernel Module
 *
 * This module provides automatic typo correction for terminal commands.
 * It uses a simple edit distance algorithm to suggest corrections
 * for commonly mistyped commands.
 *
 * Features:
 * - Automatic typo detection for common Linux commands
 * - Suggestion of closest matching command
 * - Configurable edit distance threshold
 * - Support for custom command dictionaries
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/rbtree.h>

#define MODULE_NAME "typo_corrector"
#define MAX_CMD_LEN 256
#define MAX_SUGGESTIONS 5
#define DEFAULT_MAX_DISTANCE 2

/* Common Linux commands dictionary */
static const char *common_commands[] = {
	"ls", "cd", "pwd", "mkdir", "rmdir", "rm", "cp", "mv",
	"cat", "less", "more", "head", "tail", "grep", "find",
	"chmod", "chown", "chgrp", "touch", "ln", "mount", "umount",
	"ps", "top", "htop", "kill", "killall", "nice", "renice",
	"df", "du", "free", "vmstat", "iostat", "sar",
	"ifconfig", "ip", "ping", "netstat", "ss", "traceroute",
	"ssh", "scp", "rsync", "wget", "curl",
	"apt", "apt-get", "yum", "dnf", "pacman", "zypper",
	"git", "svn", "hg", "cvs",
	"vim", "vi", "nano", "emacs", "gedit",
	"make", "gcc", "g++", "python", "python3", "perl", "ruby",
	"tar", "gzip", "gunzip", "bzip2", "xz", "zip", "unzip",
	"chmod", "chown", "chgrp",
	"systemctl", "service", "journalctl", "dmesg",
	"iptables", "nftables", "firewall-cmd",
	"docker", "podman", "kubectl",
	"ssh-keygen", "gpg", "openssl",
	NULL
};

struct command_suggestion {
	char *cmd;
	int distance;
};

struct typo_entry {
	struct rb_node node;
	char *original;
	char *corrected;
	int distance;
};

static struct rb_root typo_tree = RB_ROOT;
static int max_distance = DEFAULT_MAX_DISTANCE;
static bool enabled = true;

/* Levenshtein distance calculation */
static int levenshtein_distance(const char *s1, const char *s2)
{
	int len1 = strlen(s1);
	int len2 = strlen(s2);
	int *dp;
	int i, j, cost, result;

	dp = kmalloc((len1 + 1) * (len2 + 1) * sizeof(int), GFP_KERNEL);
	if (!dp)
		return INT_MAX;

	for (i = 0; i <= len1; i++)
		dp[i * (len2 + 1)] = i;
	for (j = 0; j <= len2; j++)
		dp[j] = j;

	for (i = 1; i <= len1; i++) {
		for (j = 1; j <= len2; j++) {
			cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
			dp[i * (len2 + 1) + j] = min3(
				dp[(i - 1) * (len2 + 1) + j] + 1,
				dp[i * (len2 + 1) + (j - 1)] + 1,
				dp[(i - 1) * (len2 + 1) + (j - 1)] + cost
			);
		}
	}

	result = dp[len1 * (len2 + 1) + len2];
	kfree(dp);
	return result;
}

/* Find closest matching command */
static const char *find_correction(const char *cmd)
{
	int i;
	int best_distance = INT_MAX;
	const char *best_match = NULL;
	int distance;

	if (!cmd || strlen(cmd) == 0)
		return NULL;

	for (i = 0; common_commands[i] != NULL; i++) {
		distance = levenshtein_distance(cmd, common_commands[i]);
		if (distance < best_distance && distance > 0) {
			best_distance = distance;
			best_match = common_commands[i];
		}
	}

	if (best_distance <= max_distance)
		return best_match;

	return NULL;
}

/* Proc file operations */
static int typo_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "Terminal Typo Corrector\n");
	seq_printf(m, "======================\n");
	seq_printf(m, "Enabled: %s\n", enabled ? "yes" : "no");
	seq_printf(m, "Max distance: %d\n", max_distance);
	seq_printf(m, "Commands in dictionary: %d\n",
		   ARRAY_SIZE(common_commands) - 1);
	return 0;
}

static int typo_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, typo_proc_show, NULL);
}

static const struct proc_ops typo_proc_ops = {
	.proc_open = typo_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int __init typo_corrector_init(void)
{
	pr_info("%s: Loading terminal typo corrector module\n", MODULE_NAME);

	/* Create proc entry */
	if (!proc_create(MODULE_NAME, 0444, NULL, &typo_proc_ops)) {
		pr_err("%s: Failed to create proc entry\n", MODULE_NAME);
		return -ENOMEM;
	}

	pr_info("%s: Module loaded successfully\n", MODULE_NAME);
	return 0;
}

static void __exit typo_corrector_exit(void)
{
	remove_proc_entry(MODULE_NAME, NULL);
	pr_info("%s: Module unloaded\n", MODULE_NAME);
}

module_init(typo_corrector_init);
module_exit(typo_corrector_exit);

module_param(enabled, bool, 0644);
MODULE_PARM_DESC(enabled, "Enable/disable typo correction (default: true)");

module_param(max_distance, int, 0644);
MODULE_PARM_DESC(max_distance, "Maximum edit distance for suggestions (default: 2)");

EXPORT_SYMBOL_GPL(find_correction);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Kernel Community");
MODULE_DESCRIPTION("Terminal Typo Correction for Linux");
MODULE_VERSION("1.0");
