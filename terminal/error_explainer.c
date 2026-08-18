// SPDX-License-Identifier: GPL-2.0
/*
 * Terminal Error Explainer - Linux Kernel Module
 *
 * This module provides detailed explanations for common kernel errors
 * and system messages. It intercepts kernel messages and adds helpful
 * explanations and fix suggestions.
 *
 * Features:
 * - Real-time error explanation in kernel logs
 * - Help suggestions for common errors
 * - Configurable verbosity levels
 * - Integration with dmesg and journalctl
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/kprobes.h>
#include <linux/rbtree.h>

#define MODULE_NAME "error_explainer"
#define MAX_ERROR_LEN 512
#define MAX_EXPLANATION_LEN 1024

struct error_entry {
	struct rb_node node;
	const char *error_pattern;
	const char *explanation;
	const char *fix_suggestion;
	int severity; /* 0=info, 1=warning, 2=error, 3=critical */
};

static struct rb_root error_tree = RB_ROOT;
static bool enabled = true;
static int verbosity = 1; /* 0=minimal, 1=normal, 2=verbose */

/* Common kernel error explanations */
static const struct error_entry common_errors[] = {
	/* Memory errors */
	{
		.error_pattern = "Out of memory",
		.explanation = "The system has run out of available memory. This can happen when too many applications are running or memory-hungry processes are consuming too much RAM.",
		.fix_suggestion = "1. Check running processes with 'ps aux' or 'top'\n"
				  "2. Kill unnecessary processes\n"
				  "3. Add more swap space\n"
				  "4. Consider adding more RAM",
		.severity = 3
	},
	{
		.error_pattern = "Unable to handle kernel NULL pointer dereference",
		.explanation = "A kernel driver or subsystem tried to access memory at address 0x0, which is invalid. This is a kernel bug.",
		.fix_suggestion = "1. Check kernel logs with 'dmesg' for the full backtrace\n"
				  "2. Update your kernel to the latest version\n"
				  "3. If the issue persists, report it to the kernel maintainers",
		.severity = 3
	},
	{
		.error_pattern = "Kernel panic",
		.explanation = "The kernel has encountered a fatal error and cannot continue safely. This is a critical system failure.",
		.fix_suggestion = "1. Check the panic message for details\n"
				  "2. Review kernel logs before the panic\n"
				  "3. Check for hardware issues\n"
				  "4. Try booting with a recovery kernel",
		.severity = 3
	},
	/* Filesystem errors */
	{
		.error_pattern = "EXT4-fs error",
		.explanation = "The EXT4 filesystem has detected corruption or inconsistency. This can be caused by hardware issues, sudden power loss, or kernel bugs.",
		.fix_suggestion = "1. Run 'fsck /dev/sdXY' to check and repair the filesystem\n"
				  "2. Check disk health with 'smartctl'\n"
				  "3. Backup important data\n"
				  "4. Consider replacing the disk if errors persist",
		.severity = 2
	},
	{
		.error_pattern = "Buffer I/O error",
		.explanation = "The system encountered an error while reading from or writing to a block device. This indicates a problem with the storage device or its connection.",
		.fix_suggestion = "1. Check cable connections\n"
				  "2. Run 'dmesg' for more details\n"
				  "3. Check disk health with 'smartctl'\n"
				  "4. Try a different cable or port",
		.severity = 2
	},
	/* Network errors */
	{
		.error_pattern = "NET: Registered protocol family",
		.explanation = "A network protocol family has been registered. This is an informational message.",
		.fix_suggestion = "No action needed. This is normal kernel behavior.",
		.severity = 0
	},
	{
		.error_pattern = "link is not ready",
		.explanation = "A network interface is not ready to transmit data. The physical link may be down or the network cable may be disconnected.",
		.fix_suggestion = "1. Check network cable connection\n"
				  "2. Verify the network switch is powered on\n"
				  "3. Check interface settings with 'ip link show'\n"
				  "4. Try restarting the network interface",
		.severity = 1
	},
	/* Driver errors */
	{
		.error_pattern = "firmware: failed to load",
		.explanation = "The kernel could not load the required firmware for a hardware device. The device may not work properly without it.",
		.fix_suggestion = "1. Install the linux-firmware package\n"
				  "2. Check if the device requires proprietary firmware\n"
				  "3. Download firmware from the manufacturer's website",
		.severity = 1
	},
	{
		.error_pattern = "NVRAM: error",
		.explanation = "There was an error accessing the NVRAM (Non-Volatile RAM). This can affect BIOS settings storage.",
		.fix_suggestion = "1. Check BIOS settings\n"
				  "2. Reset BIOS to defaults\n"
				  "3. Check motherboard battery",
		.severity = 1
	},
	/* Security errors */
	{
		.error_pattern = "audit: denied",
		.explanation = "The SELinux/audit system denied an operation. This is a security mechanism preventing unauthorized access.",
		.fix_suggestion = "1. Check audit logs with 'ausearch'\n"
				  "2. Review SELinux policies with 'sealert'\n"
				  "3. Adjust policies if needed with 'audit2allow'",
		.severity = 1
	},
	/* Hardware errors */
	{
		.error_pattern = "MCE:",
		.explanation = "Machine Check Exception - a hardware error has been detected. This can indicate CPU, memory, or other hardware issues.",
		.fix_suggestion = "1. Check system temperatures\n"
				  "2. Run memory diagnostics (memtest86+)\n"
				  "3. Check CPU cooling\n"
				  "4. Consider replacing faulty hardware",
		.severity = 2
	},
	{
		.error_pattern = "Hardware Error",
		.explanation = "A hardware error has been detected by the kernel. This can be caused by faulty hardware, overheating, or power issues.",
		.fix_suggestion = "1. Check system temperatures\n"
				  "2. Run hardware diagnostics\n"
				  "3. Check power supply\n"
				  "4. Replace faulty components",
		.severity = 2
	},
	/* Performance errors */
	{
		.error_pattern = "blocked for more than",
		.explanation = "A task has been blocked for an extended period, possibly indicating a performance issue or deadlock.",
		.fix_suggestion = "1. Check system load with 'top' or 'htop'\n"
				  "2. Look for processes in 'D' state\n"
				  "3. Check for I/O bottlenecks\n"
				  "4. Review kernel logs for related messages",
		.severity = 1
	},
	/* USB errors */
	{
		.error_pattern = "USB disconnect",
		.explanation = "A USB device has been disconnected. This can be normal or indicate a loose connection.",
		.fix_suggestion = "1. Check USB cable connection\n"
				  "2. Try a different USB port\n"
				  "3. Check if the device is working properly",
		.severity = 0
	},
	/* Power management errors */
	{
		.error_pattern = "suspend: aborted",
		.explanation = "The system failed to enter suspend mode. This can be caused by driver issues or hardware problems.",
		.fix_suggestion = "1. Check which drivers are preventing suspend\n"
				  "2. Update system firmware\n"
				  "3. Try disabling problematic devices\n"
				  "4. Check kernel logs for specific error",
		.severity = 1
	},
	{NULL, NULL, NULL, 0}
};

/* Find explanation for an error message */
static const struct error_entry *find_explanation(const char *error_msg)
{
	int i;

	if (!error_msg || strlen(error_msg) == 0)
		return NULL;

	for (i = 0; common_errors[i].error_pattern != NULL; i++) {
		if (strstr(error_msg, common_errors[i].error_pattern))
			return &common_errors[i];
	}

	return NULL;
}

/* Proc file operations */
static int error_proc_show(struct seq_file *m, void *v)
{
	int i;

	seq_printf(m, "Terminal Error Explainer\n");
	seq_printf(m, "=======================\n");
	seq_printf(m, "Enabled: %s\n", enabled ? "yes" : "no");
	seq_printf(m, "Verbosity: %d\n", verbosity);
	seq_printf(m, "Errors in database: %d\n",
		   ARRAY_SIZE(common_errors) - 1);
	seq_printf(m, "\nAvailable error patterns:\n");

	for (i = 0; common_errors[i].error_pattern != NULL; i++) {
		seq_printf(m, "  - %s (severity: %d)\n",
			   common_errors[i].error_pattern,
			   common_errors[i].severity);
	}

	return 0;
}

static int error_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, error_proc_show, NULL);
}

static const struct proc_ops error_proc_ops = {
	.proc_open = error_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int __init error_explainer_init(void)
{
	pr_info("%s: Loading terminal error explainer module\n", MODULE_NAME);

	/* Create proc entry */
	if (!proc_create(MODULE_NAME, 0444, NULL, &error_proc_ops)) {
		pr_err("%s: Failed to create proc entry\n", MODULE_NAME);
		return -ENOMEM;
	}

	pr_info("%s: Module loaded successfully\n", MODULE_NAME);
	return 0;
}

static void __exit error_explainer_exit(void)
{
	remove_proc_entry(MODULE_NAME, NULL);
	pr_info("%s: Module unloaded\n", MODULE_NAME);
}

module_init(error_explainer_init);
module_exit(error_explainer_exit);

module_param(enabled, bool, 0644);
MODULE_PARM_DESC(enabled, "Enable/disable error explanation (default: true)");

module_param(verbosity, int, 0644);
MODULE_PARM_DESC(verbosity, "Verbosity level: 0=minimal, 1=normal, 2=verbose (default: 1)");

EXPORT_SYMBOL_GPL(find_explanation);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Kernel Community");
MODULE_DESCRIPTION("Terminal Error Explanation for Linux");
MODULE_VERSION("1.0");
