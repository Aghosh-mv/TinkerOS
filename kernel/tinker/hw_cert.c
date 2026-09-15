// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Hardware Cert — kernel-level hardware certification state
 * Provides /proc/tinker/cert interface
 * Tracks hardware profiles, test results, certification status, thermal data
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include <linux/thermal.h>

#define CERT_MAX_PROFILES 32
#define CERT_NAME_MAX     64
#define CERT_RESULT_MAX   16

struct cert_profile {
	char name[CERT_NAME_MAX];
	int score;
	int tests_passed;
	int tests_total;
	int certified;
	ktime_t tested;
	ktime_t certified_time;
};

struct thermal_zone_data {
	char type[32];
	int temp;
	int critical;
	int hot;
	int warm;
};

struct cert_state {
	struct cert_profile profiles[CERT_MAX_PROFILES];
	int profile_count;
	int total_certified;
	int total_tested;
	int thermal_zones;
	struct thermal_zone_data thermal[8];
	ktime_t last_test;
	ktime_t last_cert;
	struct mutex lock;
};

static struct proc_dir_entry *cert_proc_entry;
static struct cert_state *cert_st;

static int cert_show(struct seq_file *m, void *v)
{
	int i, j;

	if (!cert_st)
		return 0;

	seq_printf(m, "=== KorrinOS Hardware Certification ===\n\n");
	seq_printf(m, "Total profiles:   %d\n", cert_st->profile_count);
	seq_printf(m, "Certified:        %d\n", cert_st->total_certified);
	seq_printf(m, "Tested:           %d\n", cert_st->total_tested);
	seq_printf(m, "Thermal zones:    %d\n\n", cert_st->thermal_zones);

	seq_printf(m, "Hardware profiles:\n");
	for (i = 0; i < cert_st->profile_count; i++) {
		struct cert_profile *p = &cert_st->profiles[i];
		seq_printf(m, "  %-20s score=%3d passed=%d/%d [%s]\n",
			   p->name, p->score, p->tests_passed, p->tests_total,
			   p->certified ? "CERTIFIED" : "tested");
	}

	seq_printf(m, "\nThermal zones:\n");
	for (j = 0; j < cert_st->thermal_zones && j < 8; j++) {
		struct thermal_zone_data *tz = &cert_st->thermal[j];
		seq_printf(m, "  %-20s %3d°C  critical=%d°C  hot=%d°C\n",
			   tz->type, tz->temp, tz->critical, tz->hot);
	}

	return 0;
}

static int cert_open(struct inode *inode, struct file *file)
{
	return single_open(file, cert_show, NULL);
}

static ssize_t cert_write(struct file *file, const char __user *buf,
			  size_t count, loff_t *ppos)
{
	char kbuf[256];
	char cmd[32], name[CERT_NAME_MAX];
	int ret, score, passed, total;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&cert_st->lock);

	ret = sscanf(kbuf, "%31s %63s", cmd, name);
	if (ret < 1) {
		mutex_unlock(&cert_st->lock);
		return -EINVAL;
	}

	if (strcmp(cmd, "test") == 0 && ret >= 5) {
		struct cert_profile *p = NULL;
		sscanf(kbuf, "%*s %*s %d %d %d", &score, &passed, &total);
		for (i = 0; i < cert_st->profile_count; i++) {
			if (strcmp(cert_st->profiles[i].name, name) == 0) {
				p = &cert_st->profiles[i];
				break;
			}
		}
		if (!p && cert_st->profile_count < CERT_MAX_PROFILES) {
			p = &cert_st->profiles[cert_st->profile_count++];
			strscpy(p->name, name, CERT_NAME_MAX);
		}
		if (p) {
			p->score = score;
			p->tests_passed = passed;
			p->tests_total = total;
			p->tested = ktime_get_real();
			cert_st->total_tested++;
			cert_st->last_test = ktime_get_real();
		}
	} else if (strcmp(cmd, "certify") == 0 && ret >= 2) {
		for (i = 0; i < cert_st->profile_count; i++) {
			if (strcmp(cert_st->profiles[i].name, name) == 0) {
				cert_st->profiles[i].certified = 1;
				cert_st->profiles[i].certified_time = ktime_get_real();
				cert_st->total_certified++;
				cert_st->last_cert = ktime_get_real();
				break;
			}
		}
	} else if (strcmp(cmd, "thermal") == 0) {
		int idx, temp;
		char tz_type[32];
		sscanf(kbuf, "%*s %d %31s %d", &idx, tz_type, &temp);
		if (idx >= 0 && idx < 8) {
			strscpy(cert_st->thermal[idx].type, tz_type, 32);
			cert_st->thermal[idx].temp = temp;
			if (cert_st->thermal_zones <= idx)
				cert_st->thermal_zones = idx + 1;
		}
	} else {
		mutex_unlock(&cert_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&cert_st->lock);
	return count;
}

static const struct proc_ops cert_proc_ops = {
	.proc_open    = cert_open,
	.proc_write   = cert_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init cert_init(void)
{
	cert_st = kzalloc(sizeof(*cert_st), GFP_KERNEL);
	if (!cert_st)
		return -ENOMEM;

	mutex_init(&cert_st->lock);

	cert_proc_entry = proc_create("tinker/cert", 0644, NULL,
				      &cert_proc_ops);
	if (!cert_proc_entry) {
		kfree(cert_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: hardware cert loaded\n");
	return 0;
}

static void __exit cert_exit(void)
{
	proc_remove(cert_proc_entry);
	kfree(cert_st);
	pr_info("KorrinOS: hardware cert unloaded\n");
}

module_init(cert_init);
module_exit(cert_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel hardware certification state");
MODULE_VERSION("1.0");
