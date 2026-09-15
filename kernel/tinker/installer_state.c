// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Installer State — kernel-level installation tracking
 * Provides /proc/tinker/installer interface
 * Tracks install phases, partition state, bootloader, user setup, validation
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>

#define INSTALLER_PHASE_INIT      0
#define INSTALLER_PHASE_DETECT    1
#define INSTALLER_PHASE_PARTITION 2
#define INSTALLER_PHASE_COPY      3
#define INSTALLER_PHASE_BOOT      4
#define INSTALLER_PHASE_USER      5
#define INSTALLER_PHASE_CONFIG    6
#define INSTALLER_PHASE_COMPLETE  7
#define INSTALLER_PHASE_ERROR     8

#define DISK_MAX 8
#define DISK_NAME_MAX 32

struct disk_info {
	char name[DISK_NAME_MAX];
	unsigned long size_gb;
	int partitioned;
	int has_root;
	int has_efi;
};

struct installer_state {
	int current_phase;
	int percent_complete;
	struct disk_info disks[DISK_MAX];
	int disk_count;
	char target_disk[DISK_NAME_MAX];
	char install_type[32];
	char partition_scheme[8];
	char filesystem[16];
	char username[64];
	char hostname[64];
	char timezone[64];
	char locale[32];
	char keyboard[16];
	int encryption_enabled;
	int lvm_enabled;
	int bootloader_installed;
	int user_created;
	int services_enabled;
	int validation_passed;
	char last_error[256];
	ktime_t install_start;
	ktime_t install_end;
	struct mutex lock;
};

static struct proc_dir_entry *inst_proc_entry;
static struct installer_state *inst_st;

static const char *phase_str(int phase)
{
	switch (phase) {
	case INSTALLER_PHASE_INIT:      return "init";
	case INSTALLER_PHASE_DETECT:    return "detect";
	case INSTALLER_PHASE_PARTITION: return "partition";
	case INSTALLER_PHASE_COPY:      return "copy";
	case INSTALLER_PHASE_BOOT:      return "bootloader";
	case INSTALLER_PHASE_USER:      return "user";
	case INSTALLER_PHASE_CONFIG:    return "config";
	case INSTALLER_PHASE_COMPLETE:  return "complete";
	case INSTALLER_PHASE_ERROR:     return "error";
	default:                        return "unknown";
	}
}

static int installer_show(struct seq_file *m, void *v)
{
	int i;
	unsigned long elapsed_ms = 0;

	if (!inst_st)
		return 0;

	if (inst_st->install_start && inst_st->install_end) {
		elapsed_ms = ktime_ms_delta(inst_st->install_end,
					    inst_st->install_start);
	} else if (inst_st->install_start) {
		elapsed_ms = ktime_ms_delta(ktime_get(),
					    inst_st->install_start);
	}

	seq_printf(m, "=== KorrinOS Installer State ===\n\n");
	seq_printf(m, "Phase:            %s\n", phase_str(inst_st->current_phase));
	seq_printf(m, "Progress:         %d%%\n", inst_st->percent_complete);
	seq_printf(m, "Elapsed:          %lu.%lus\n",
		   elapsed_ms / 1000, (elapsed_ms % 1000) / 100);
	seq_printf(m, "\nConfiguration:\n");
	seq_printf(m, "  Target disk:    %s\n", inst_st->target_disk);
	seq_printf(m, "  Install type:   %s\n", inst_st->install_type);
	seq_printf(m, "  Partition:      %s\n", inst_st->partition_scheme);
	seq_printf(m, "  Filesystem:     %s\n", inst_st->filesystem);
	seq_printf(m, "  Username:       %s\n", inst_st->username);
	seq_printf(m, "  Hostname:       %s\n", inst_st->hostname);
	seq_printf(m, "  Timezone:       %s\n", inst_st->timezone);
	seq_printf(m, "  Locale:         %s\n", inst_st->locale);
	seq_printf(m, "  Keyboard:       %s\n", inst_st->keyboard);
	seq_printf(m, "  Encryption:     %s\n", inst_st->encryption_enabled ? "yes" : "no");
	seq_printf(m, "  LVM:            %s\n", inst_st->lvm_enabled ? "yes" : "no");
	seq_printf(m, "\nStatus:\n");
	seq_printf(m, "  Bootloader:     %s\n", inst_st->bootloader_installed ? "installed" : "pending");
	seq_printf(m, "  User created:   %s\n", inst_st->user_created ? "yes" : "no");
	seq_printf(m, "  Services:       %s\n", inst_st->services_enabled ? "enabled" : "pending");
	seq_printf(m, "  Validation:     %s\n", inst_st->validation_passed ? "passed" : "not run");
	seq_printf(m, "\nDetected disks:\n");

	for (i = 0; i < inst_st->disk_count; i++) {
		struct disk_info *d = &inst_st->disks[i];
		seq_printf(m, "  %-12s %luGB %s%s%s\n",
			   d->name, d->size_gb,
			   d->partitioned ? "part " : "",
			   d->has_root ? "root " : "",
			   d->has_efi ? "efi" : "");
	}

	if (inst_st->last_error[0])
		seq_printf(m, "\nError: %s\n", inst_st->last_error);

	return 0;
}

static int installer_open(struct inode *inode, struct file *file)
{
	return single_open(file, installer_show, NULL);
}

static ssize_t installer_write(struct file *file, const char __user *buf,
			       size_t count, loff_t *ppos)
{
	char kbuf[512];
	char cmd[32], arg1[128], arg2[128];
	int ret;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&inst_st->lock);

	ret = sscanf(kbuf, "%31s %127s %127s", cmd, arg1, arg2);

	if (strcmp(cmd, "phase") == 0 && ret >= 2) {
		inst_st->current_phase = simple_strtoul(arg1, NULL, 10);
		if (inst_st->current_phase == INSTALLER_PHASE_INIT)
			inst_st->install_start = ktime_get_real();
	} else if (strcmp(cmd, "progress") == 0 && ret >= 2) {
		inst_st->percent_complete = simple_strtoul(arg1, NULL, 10);
	} else if (strcmp(cmd, "target") == 0 && ret >= 2) {
		strscpy(inst_st->target_disk, arg1, DISK_NAME_MAX);
	} else if (strcmp(cmd, "type") == 0 && ret >= 2) {
		strscpy(inst_st->install_type, arg1, sizeof(inst_st->install_type));
	} else if (strcmp(cmd, "scheme") == 0 && ret >= 2) {
		strscpy(inst_st->partition_scheme, arg1, sizeof(inst_st->partition_scheme));
	} else if (strcmp(cmd, "filesystem") == 0 && ret >= 2) {
		strscpy(inst_st->filesystem, arg1, sizeof(inst_st->filesystem));
	} else if (strcmp(cmd, "user") == 0 && ret >= 2) {
		strscpy(inst_st->username, arg1, sizeof(inst_st->username));
		inst_st->user_created = 1;
	} else if (strcmp(cmd, "hostname") == 0 && ret >= 2) {
		strscpy(inst_st->hostname, arg1, sizeof(inst_st->hostname));
	} else if (strcmp(cmd, "timezone") == 0 && ret >= 2) {
		strscpy(inst_st->timezone, arg1, sizeof(inst_st->timezone));
	} else if (strcmp(cmd, "locale") == 0 && ret >= 2) {
		strscpy(inst_st->locale, arg1, sizeof(inst_st->locale));
	} else if (strcmp(cmd, "keyboard") == 0 && ret >= 2) {
		strscpy(inst_st->keyboard, arg1, sizeof(inst_st->keyboard));
	} else if (strcmp(cmd, "disk-add") == 0 && ret >= 3) {
		if (inst_st->disk_count < DISK_MAX) {
			struct disk_info *d = &inst_st->disks[inst_st->disk_count++];
			strscpy(d->name, arg1, DISK_NAME_MAX);
			d->size_gb = simple_strtoul(arg2, NULL, 10);
		}
	} else if (strcmp(cmd, "bootloader") == 0 && ret >= 2) {
		inst_st->bootloader_installed = (strcmp(arg1, "done") == 0);
	} else if (strcmp(cmd, "services") == 0 && ret >= 2) {
		inst_st->services_enabled = (strcmp(arg1, "done") == 0);
	} else if (strcmp(cmd, "validate") == 0 && ret >= 2) {
		inst_st->validation_passed = (strcmp(arg1, "pass") == 0);
		if (inst_st->validation_passed)
			inst_st->install_end = ktime_get_real();
	} else if (strcmp(cmd, "error") == 0) {
		inst_st->current_phase = INSTALLER_PHASE_ERROR;
		sscanf(kbuf, "%*s %255[^\n]", inst_st->last_error);
	} else if (strcmp(cmd, "complete") == 0) {
		inst_st->current_phase = INSTALLER_PHASE_COMPLETE;
		inst_st->percent_complete = 100;
		inst_st->install_end = ktime_get_real();
	} else if (strcmp(cmd, "reset") == 0) {
		memset(inst_st, 0, sizeof(*inst_st));
		mutex_init(&inst_st->lock);
	} else {
		mutex_unlock(&inst_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&inst_st->lock);
	return count;
}

static const struct proc_ops installer_proc_ops = {
	.proc_open    = installer_open,
	.proc_write   = installer_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init installer_init(void)
{
	inst_st = kzalloc(sizeof(*inst_st), GFP_KERNEL);
	if (!inst_st)
		return -ENOMEM;

	mutex_init(&inst_st->lock);
	inst_st->current_phase = INSTALLER_PHASE_INIT;

	inst_proc_entry = proc_create("tinker/installer", 0644, NULL,
				      &installer_proc_ops);
	if (!inst_proc_entry) {
		kfree(inst_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: installer state loaded\n");
	return 0;
}

static void __exit installer_exit(void)
{
	proc_remove(inst_proc_entry);
	kfree(inst_st);
	pr_info("KorrinOS: installer state unloaded\n");
}

module_init(installer_init);
module_exit(installer_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel installer state tracker");
MODULE_VERSION("1.0");
