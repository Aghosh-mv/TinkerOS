// SPDX-License-Identifier: GPL-2.0
/*
 * Smart Input System - Linux Kernel Module
 *
 * Provides global smart input features for all Linux applications:
 * - Accent character picker (long-press to see variants)
 * - Smart autocorrect with ghost text + Tab accept
 * - Timestamp converter (Unix → human readable)
 * - Unit converter (km↔miles, kg↔lbs, etc.)
 * - Clipboard history
 *
 * Architecture:
 * - Kernel provides data tables, infrastructure, and proc/sys interfaces
 * - Userspace apps query via /proc/smart_input/ or netlink
 * - Ghost text appears as grey overlay, Tab accepts it
 *
 * This module is the backend; userspace (DE/terminals/editors) provides
 * the visual overlay based on kernel suggestions.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/timer.h>
#include <linux/input.h>
#include <linux/netlink.h>
#include <linux/skbuff.h>
#include <linux/workqueue.h>
#include <linux/ktime.h>

#define MODULE_NAME "smart_input"
#define MAX_ACCENTS 8
#define MAX_WORD_LEN 64
#define MAX_SUGGESTION_LEN 128
#define MAX_CLIPBOARD_HISTORY 10
#define LONGPRESS_MS 500

/* ==================== ACCENT CHARACTER TABLE ==================== */

struct accent_entry {
	char base;           /* base character */
	const char *variants[MAX_ACCENTS]; /* accented variants */
	int count;
};

/* Complete accent map for international characters */
static const struct accent_entry accent_table[] = {
	/* Vowels */
	{'a', {"à", "á", "â", "ã", "ä", "å", "ā", "ă"}, 8},
	{'e', {"è", "é", "ê", "ë", "ē", "ė", "ę", "ě"}, 8},
	{'i', {"ì", "í", "î", "ï", "ī", "į", "ı", "ǐ"}, 8},
	{'o', {"ò", "ó", "ô", "õ", "ö", "ø", "ō", "ő"}, 8},
	{'u', {"ù", "ú", "û", "ü", "ū", "ų", "ů", "ű"}, 8},
	/* Consonants */
	{'c', {"ç", "ć", "č", "ċ", "ĉ", "ḉ", "ȼ", "ƈ"}, 8},
	{'n', {"ñ", "ń", "ņ", "ň", "ŋ", "ṅ", "ṇ", "ṅ"}, 8},
	{'s', {"ß", "ś", "ŝ", "ş", "š", "ș", "ṡ", "ṣ"}, 8},
	{'z', {"ź", "ż", "ž", "ẑ", "ẓ", "ẕ", "ż", "ź"}, 8},
	{'y', {"ý", "ÿ", "ŷ", "ȳ", "ẏ", "ǘ", "ỳ", "ỹ"}, 8},
	{'l', {"ł", "ĺ", "ļ", "ľ", "ŀ", "ĺ", "ḷ", "ḹ"}, 8},
	{'r', {"ŕ", "ŗ", "ř", "ṙ", "ṛ", "ṝ", "ṟ", "ṛ"}, 8},
	{'t', {"ţ", "ť", "ṫ", "ṭ", "ṯ", "ṱ", "ẗ", "ŧ"}, 8},
	{'d', {"ď", "ḋ", "ḍ", "ḏ", "ḑ", "ḑ", "ḋ", "ḍ"}, 8},
	/* Special */
	{'A', {"À", "Á", "Â", "Ã", "Ä", "Å", "Ā", "Ă"}, 8},
	{'E', {"È", "É", "Ê", "Ë", "Ē", "Ė", "Ę", "Ě"}, 8},
	{'I', {"Ì", "Í", "Î", "Ï", "Ī", "Į", "İ", "Ǐ"}, 8},
	{'O', {"Ò", "Ó", "Ô", "Õ", "Ö", "Ø", "Ō", "Ő"}, 8},
	{'U', {"Ù", "Ú", "Û", "Ü", "Ū", "Ų", "Ů", "Ű"}, 8},
	{'C', {"Ç", "Ć", "Č", "Ċ", "Ĉ", "Ḉ", "Ȼ", "Ɔ"}, 8},
	{'N', {"Ñ", "Ń", "Ņ", "Ň", "Ŋ", "Ṅ", "Ṇ", "Ṅ"}, 8},
	{'S', {"Ś", "Ŝ", "Ş", "Š", "Ș", "Ṡ", "Ṣ", "Ṩ"}, 8},
	{'Z', {"Ź", "Ż", "Ž", "Ẑ", "Ẓ", "Ẕ", "Ż", "Ź"}, 8},
	{0, {NULL}, 0}
};

/* ==================== AUTOCORRECT TABLE ==================== */

struct autocorrect_entry {
	const char *wrong;
	const char *correct;
};

/* Common English typos */
static const struct autocorrect_entry autocorrect_table[] = {
	{"teh", "the"},
	{"recieve", "receive"},
	{"seperate", "separate"},
	{"occured", "occurred"},
	{"definately", "definitely"},
	{"goverment", "government"},
	{"accomodate", "accommodate"},
	{"untill", "until"},
	{"wierd", "weird"},
	{"thier", "their"},
	{"adn", "and"},
	{"taht", "that"},
	{"wiht", "with"},
	{"jsut", "just"},
	{"nto", "not"},
	{"fo", "of"},
	{"ot", "to"},
	{"ti", "it"},
	{"nt", "not"},
	{"nad", "and"},
	{"ls", "is"},
	{"th", "the"},
	{"ta", "to"},
	{"adn", "and"},
	{"htat", "that"},
	{"hwat", "what"},
	{"hwo", "how"},
	{"whne", "when"},
	{"whre", "where"},
	{"wtih", "with"},
	{"fro", "for"},
	{"asn", "as"},
	{"ot", "to"},
	{"nad", "and"},
	{"yea", "yes"},
	{"nah", "no"},
	{"pls", "please"},
	{"thx", "thanks"},
	{"u", "you"},
	{"r", "are"},
	{"ur", "your"},
	{"n", "and"},
	{"w/", "with"},
	{"w/o", "without"},
	{"bc", "because"},
	{"b/c", "because"},
	{"tbh", "to be honest"},
	{"imo", "in my opinion"},
	{"imho", "in my humble opinion"},
	{"afaik", "as far as I know"},
	{"iirc", "if I recall correctly"},
	{"fwiw", "for what it's worth"},
	{"ngl", "not gonna lie"},
	{"smh", "shaking my head"},
	{"tbt", "throwback thursday"},
	{"ftw", "for the win"},
	{"irl", "in real life"},
	{"brb", "be right back"},
	{"afk", "away from keyboard"},
	{"gg", "good game"},
	{"wp", "well played"},
	{"glhf", "good luck have fun"},
	{NULL, NULL}
};

/* ==================== UNIT CONVERSION TABLE ==================== */

struct unit_entry {
	const char *from_unit;
	const char *to_unit;
	double factor;
	double offset; /* for C↔F style conversions */
};

static const struct unit_entry unit_table[] = {
	/* Distance */
	{"km", "mi", 0.621371, 0},
	{"mi", "km", 1.60934, 0},
	{"m", "ft", 3.28084, 0},
	{"ft", "m", 0.3048, 0},
	{"cm", "in", 0.393701, 0},
	{"in", "cm", 2.54, 0},
	{"mm", "in", 0.0393701, 0},
	/* Weight */
	{"kg", "lb", 2.20462, 0},
	{"lb", "kg", 0.453592, 0},
	{"g", "oz", 0.035274, 0},
	{"oz", "g", 28.3495, 0},
	{"mg", "gr", 0.0154324, 0},
	/* Temperature */
	{"C", "F", 1.8, 32},
	{"F", "C", 0.555556, -32},
	{"C", "K", 1, 273.15},
	{"K", "C", 1, -273.15},
	/* Volume */
	{"L", "gal", 0.264172, 0},
	{"gal", "L", 3.78541, 0},
	{"ml", "fl_oz", 0.033814, 0},
	{"fl_oz", "ml", 29.5735, 0},
	/* Speed */
	{"kph", "mph", 0.621371, 0},
	{"mph", "kph", 1.60934, 0},
	{"m/s", "kph", 3.6, 0},
	{"m/s", "mph", 2.23694, 0},
	/* Data */
	{"GB", "MB", 1024, 0},
	{"MB", "GB", 0.000976562, 0},
	{"TB", "GB", 1024, 0},
	{"GB", "TB", 0.000976562, 0},
	{"KB", "B", 1024, 0},
	{"MB", "KB", 1024, 0},
	{NULL, NULL, 0, 0}
};

/* ==================== CLIPBOARD HISTORY ==================== */

struct clipboard_entry {
	char *data;
	size_t len;
	ktime_t timestamp;
};

static struct clipboard_entry clipboard_history[MAX_CLIPBOARD_HISTORY];
static int clipboard_head = 0;
static int clipboard_count = 0;
static DEFINE_SPINLOCK(clipboard_lock);

/* ==================== LONG-PRESS DETECTION ==================== */

struct longpress_state {
	struct timer_list timer;
	struct input_handle *handle;
	bool active;
	char last_key;
	ktime_t press_start;
};

static struct longpress_state longpress_states[16]; /* max 16 input devices */

/* ==================== KERNEL VARIABLES ==================== */

static bool accent_enabled = true;
static bool autocorrect_enabled = true;
static bool unit_converter_enabled = true;
static bool timestamp_converter_enabled = true;
static bool clipboard_history_enabled = true;
static int longpress_delay_ms = LONGPRESS_MS;

/* Netlink socket for userspace communication */
static struct sock *smart_input_sock;

/* Work queue for deferred processing */
static struct workqueue_struct *smart_input_wq;

/* ==================== ACCENT LOOKUP ==================== */

/**
 * find_accents - Find accent variants for a character
 * @c: The base character
 * @variants: Output array to store variant strings
 *
 * Returns number of variants found, or 0 if none.
 */
int find_accents(char c, const char **variants)
{
	int i;

	if (!accent_enabled)
		return 0;

	for (i = 0; accent_table[i].base; i++) {
		if (accent_table[i].base == c) {
			int j;
			for (j = 0; j < accent_table[i].count && j < MAX_ACCENTS; j++)
				variants[j] = accent_table[i].variants[j];
			return accent_table[i].count;
		}
	}
	return 0;
}
EXPORT_SYMBOL(find_accents);

/**
 * find_autocorrect - Find autocorrect suggestion for a word
 * @word: The potentially misspelled word
 *
 * Returns pointer to correct spelling, or NULL if no suggestion.
 */
const char *find_autocorrect(const char *word)
{
	int i;

	if (!autocorrect_enabled || !word)
		return NULL;

	for (i = 0; autocorrect_table[i].wrong; i++) {
		if (strcasecmp(word, autocorrect_table[i].wrong) == 0)
			return autocorrect_table[i].correct;
	}
	return NULL;
}
EXPORT_SYMBOL(find_autocorrect);

/**
 * find_unit_conversion - Find unit conversion for a value
 * @value: Numeric value
 * @from_unit: Source unit string
 * @converted_value: Output converted value
 * @to_unit: Output target unit string (caller must free)
 *
 * Returns 0 on success, -1 if no conversion found.
 */
int find_unit_conversion(double value, const char *from_unit,
			double *converted_value, char **to_unit)
{
	int i;

	if (!unit_converter_enabled || !from_unit)
		return -1;

	for (i = 0; unit_table[i].from_unit; i++) {
		if (strcmp(from_unit, unit_table[i].from_unit) == 0) {
			*converted_value = value * unit_table[i].factor +
					   unit_table[i].offset;
			*to_unit = kmalloc(strlen(unit_table[i].to_unit) + 1, GFP_KERNEL);
			if (*to_unit)
				strcpy(*to_unit, unit_table[i].to_unit);
			return 0;
		}
	}
	return -1;
}
EXPORT_SYMBOL(find_unit_conversion);

/**
 * is_timestamp - Check if a number looks like a Unix timestamp
 * @value: Numeric value to check
 *
 * Returns true if the value looks like a reasonable Unix timestamp.
 */
bool is_timestamp(double value)
{
	/* Unix timestamps are typically between 2000-2100 */
	/* In seconds: 946684800 (2000) to 4102444800 (2100) */
	if (value >= 946684800.0 && value <= 4102444800.0)
		return true;
	return false;
}
EXPORT_SYMBOL(is_timestamp);

/* ==================== CLIPBOARD FUNCTIONS ==================== */

/**
 * clipboard_add - Add data to clipboard history
 * @data: Data to store
 * @len: Length of data
 */
void clipboard_add(const char *data, size_t len)
{
	unsigned long flags;

	if (!clipboard_history_enabled || !data || len == 0)
		return;

	spin_lock_irqsave(&clipboard_lock, flags);

	/* Free old entry if needed */
	if (clipboard_history[clipboard_head].data)
		kfree(clipboard_history[clipboard_head].data);

	/* Store new entry */
	clipboard_history[clipboard_head].data = kmalloc(len + 1, GFP_ATOMIC);
	if (clipboard_history[clipboard_head].data) {
		memcpy(clipboard_history[clipboard_head].data, data, len);
		clipboard_history[clipboard_head].data[len] = '\0';
		clipboard_history[clipboard_head].len = len;
		clipboard_history[clipboard_head].timestamp = ktime_get();
	}

	/* Advance head */
	clipboard_head = (clipboard_head + 1) % MAX_CLIPBOARD_HISTORY;
	if (clipboard_count < MAX_CLIPBOARD_HISTORY)
		clipboard_count++;

	spin_unlock_irqrestore(&clipboard_lock, flags);
}
EXPORT_SYMBOL(clipboard_add);

/**
 * clipboard_get - Get entry from clipboard history
 * @index: Index (0 = most recent)
 * @data: Output pointer to data (do not free)
 * @len: Output length
 * @timestamp: Output timestamp
 *
 * Returns 0 on success, -1 if index out of range.
 */
int clipboard_get(int index, const char **data, size_t *len, ktime_t *timestamp)
{
	int pos;
	unsigned long flags;

	if (index < 0 || index >= clipboard_count)
		return -1;

	spin_lock_irqsave(&clipboard_lock, flags);

	pos = (clipboard_head - 1 - index + MAX_CLIPBOARD_HISTORY) % MAX_CLIPBOARD_HISTORY;
	*data = clipboard_history[pos].data;
	*len = clipboard_history[pos].len;
	*timestamp = clipboard_history[pos].timestamp;

	spin_unlock_irqrestore(&clipboard_lock, flags);
	return 0;
}
EXPORT_SYMBOL(clipboard_get);

/**
 * clipboard_count_get - Get number of clipboard entries
 */
int clipboard_count_get(void)
{
	return clipboard_count;
}
EXPORT_SYMBOL(clipboard_count_get);

/* ==================== PROC INTERFACE ==================== */

static int smart_input_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "Smart Input System v1.0\n");
	seq_printf(m, "=======================\n");
	seq_printf(m, "\nFeature Status:\n");
	seq_printf(m, "  Accent picker:      %s\n", accent_enabled ? "ON" : "OFF");
	seq_printf(m, "  Autocorrect:        %s\n", autocorrect_enabled ? "ON" : "OFF");
	seq_printf(m, "  Unit converter:     %s\n", unit_converter_enabled ? "ON" : "OFF");
	seq_printf(m, "  Timestamp converter:%s\n", timestamp_converter_enabled ? "ON" : "OFF");
	seq_printf(m, "  Clipboard history:  %s\n", clipboard_history_enabled ? "ON" : "OFF");
	seq_printf(m, "\nLong-press delay: %d ms\n", longpress_delay_ms);
	seq_printf(m, "\nClipboard entries: %d/%d\n", clipboard_count, MAX_CLIPBOARD_HISTORY);
	return 0;
}

static int smart_input_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, smart_input_proc_show, NULL);
}

static ssize_t smart_input_proc_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[128];
	char cmd[32], val[32];

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	if (sscanf(kbuf, "%31s %31s", cmd, val) == 2) {
		if (strcmp(cmd, "accent") == 0)
			accent_enabled = (strcmp(val, "on") == 0);
		else if (strcmp(cmd, "autocorrect") == 0)
			autocorrect_enabled = (strcmp(val, "on") == 0);
		else if (strcmp(cmd, "units") == 0)
			unit_converter_enabled = (strcmp(val, "on") == 0);
		else if (strcmp(cmd, "timestamp") == 0)
			timestamp_converter_enabled = (strcmp(val, "on") == 0);
		else if (strcmp(cmd, "clipboard") == 0)
			clipboard_history_enabled = (strcmp(val, "on") == 0);
		else if (strcmp(cmd, "delay") == 0)
			longpress_delay_ms = simple_strtol(val, NULL, 10);
	}

	return count;
}

static const struct proc_ops smart_input_proc_ops = {
	.proc_open = smart_input_proc_open,
	.proc_read = seq_read,
	.proc_write = smart_input_proc_write,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/* ==================== ACCENT PROC ==================== */

static int accent_proc_show(struct seq_file *m, void *v)
{
	int i, j;

	seq_printf(m, "Accent Character Table\n");
	seq_printf(m, "======================\n\n");

	for (i = 0; accent_table[i].base; i++) {
		seq_printf(m, "'%c' → ", accent_table[i].base);
		for (j = 0; j < accent_table[i].count; j++)
			seq_printf(m, "%d:%s  ", j + 1, accent_table[i].variants[j]);
		seq_printf(m, "\n");
	}

	return 0;
}

static int accent_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, accent_proc_show, NULL);
}

static const struct proc_ops accent_proc_ops = {
	.proc_open = accent_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/* ==================== AUTOCORRECT PROC ==================== */

static int autocorrect_proc_show(struct seq_file *m, void *v)
{
	int i;

	seq_printf(m, "Autocorrect Dictionary\n");
	seq_printf(m, "======================\n\n");

	for (i = 0; autocorrect_table[i].wrong; i++) {
		seq_printf(m, "%-20s → %s\n",
			   autocorrect_table[i].wrong,
			   autocorrect_table[i].correct);
	}

	return 0;
}

static int autocorrect_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, autocorrect_proc_show, NULL);
}

static const struct proc_ops autocorrect_proc_ops = {
	.proc_open = autocorrect_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/* ==================== UNITS PROC ==================== */

static int units_proc_show(struct seq_file *m, void *v)
{
	int i;

	seq_printf(m, "Unit Conversion Table\n");
	seq_printf(m, "=====================\n\n");

	for (i = 0; unit_table[i].from_unit; i++) {
		seq_printf(m, "1 %-6s = %.6g %s\n",
			   unit_table[i].from_unit,
			   unit_table[i].factor + unit_table[i].offset,
			   unit_table[i].to_unit);
	}

	return 0;
}

static int units_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, units_proc_show, NULL);
}

static const struct proc_ops units_proc_ops = {
	.proc_open = units_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/* ==================== CLIPBOARD PROC ==================== */

static int clipboard_proc_show(struct seq_file *m, void *v)
{
	int i;
	const char *data;
	size_t len;
	ktime_t ts;

	seq_printf(m, "Clipboard History\n");
	seq_printf(m, "=================\n\n");

	if (clipboard_count == 0) {
		seq_printf(m, "(empty)\n");
		return 0;
	}

	for (i = 0; i < clipboard_count; i++) {
		if (clipboard_get(i, &data, &len, &ts) == 0) {
			seq_printf(m, "[%d] (%zu bytes, %lld ms ago) %.*s\n",
				   i, len,
				   ktime_ms_delta(ktime_get(), ts),
				   (int)min(len, (size_t)80),
				   data ? data : "(null)");
		}
	}

	return 0;
}

static int clipboard_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, clipboard_proc_show, NULL);
}

static const struct proc_ops clipboard_proc_ops = {
	.proc_open = clipboard_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/* ==================== NETLINK COMMUNICATION ==================== */

/* Netlink message types */
#define SMART_INPUT_MSG_ACCENT    1
#define SMART_INPUT_MSG_AUTOCORR  2
#define SMART_INPUT_MSG_UNIT      3
#define SMART_INPUT_MSG_TIMESTAMP 4
#define SMART_INPUT_MSG_CLIPBOARD 5

struct smart_input_msg {
	int type;
	int length;
	char data[0];
};

/**
 * smart_input_send_to_userspace - Send suggestion to userspace
 * @type: Message type
 * @data: Data to send
 * @len: Data length
 */
void smart_input_send_to_userspace(int type, const char *data, int len)
{
	struct sk_buff *skb;
	struct nlmsghdr *nlh;
	struct smart_input_msg *msg;

	if (!smart_input_sock)
		return;

	skb = nlmsg_new(len + sizeof(*msg), GFP_KERNEL);
	if (!skb)
		return;

	nlh = nlmsg_put(skb, 0, 0, NLMSG_DONE, len + sizeof(*msg), 0);
	if (!nlh) {
		kfree_skb(skb);
		return;
	}

	msg = nlmsg_data(nlh);
	msg->type = type;
	msg->length = len;
	memcpy(msg->data, data, len);

	/* Send to userspace (group 1) */
	netlink_broadcast(smart_input_sock, skb, 0, 1, GFP_KERNEL);
}
EXPORT_SYMBOL(smart_input_send_to_userspace);

/* ==================== MODULE INIT/EXIT ==================== */

static int __init smart_input_init(void)
{
	struct proc_dir_entry *proc_dir;

	pr_info("%s: Loading Smart Input System\n", MODULE_NAME);

	/* Create proc directory */
	proc_dir = proc_mkdir(MODULE_NAME, NULL);
	if (!proc_dir) {
		pr_err("%s: Failed to create proc directory\n", MODULE_NAME);
		return -ENOMEM;
	}

	/* Create proc entries */
	if (!proc_create("status", 0644, proc_dir, &smart_input_proc_ops))
		goto err_cleanup;

	if (!proc_create("accents", 0444, proc_dir, &accent_proc_ops))
		goto err_cleanup;

	if (!proc_create("autocorrect", 0444, proc_dir, &autocorrect_proc_ops))
		goto err_cleanup;

	if (!proc_create("units", 0444, proc_dir, &units_proc_ops))
		goto err_cleanup;

	if (!proc_create("clipboard", 0444, proc_dir, &clipboard_proc_ops))
		goto err_cleanup;

	/* Create workqueue */
	smart_input_wq = create_workqueue("smart_input_wq");
	if (!smart_input_wq) {
		pr_err("%s: Failed to create workqueue\n", MODULE_NAME);
		goto err_cleanup;
	}

	pr_info("%s: Module loaded successfully\n", MODULE_NAME);
	pr_info("%s: Access features via /proc/%s/\n", MODULE_NAME, MODULE_NAME);
	return 0;

err_cleanup:
	remove_proc_subtree(MODULE_NAME, NULL);
	return -ENOMEM;
}

static void __exit smart_input_exit(void)
{
	int i;

	/* Clean up clipboard */
	for (i = 0; i < MAX_CLIPBOARD_HISTORY; i++) {
		if (clipboard_history[i].data)
			kfree(clipboard_history[i].data);
	}

	/* Destroy workqueue */
	if (smart_input_wq)
		destroy_workqueue(smart_input_wq);

	/* Remove proc entries */
	remove_proc_subtree(MODULE_NAME, NULL);

	pr_info("%s: Module unloaded\n", MODULE_NAME);
}

module_init(smart_input_init);
module_exit(smart_input_exit);

/* Module parameters */
module_param(accent_enabled, bool, 0644);
MODULE_PARM_DESC(accent_enabled, "Enable accent character picker (default: true)");

module_param(autocorrect_enabled, bool, 0644);
MODULE_PARM_DESC(autocorrect_enabled, "Enable smart autocorrect (default: true)");

module_param(unit_converter_enabled, bool, 0644);
MODULE_PARM_DESC(unit_converter_enabled, "Enable unit converter (default: true)");

module_param(timestamp_converter_enabled, bool, 0644);
MODULE_PARM_DESC(timestamp_converter_enabled, "Enable timestamp converter (default: true)");

module_param(clipboard_history_enabled, bool, 0644);
MODULE_PARM_DESC(clipboard_history_enabled, "Enable clipboard history (default: true)");

module_param(longpress_delay_ms, int, 0644);
MODULE_PARM_DESC(longpress_delay_ms, "Long-press delay in milliseconds (default: 500)");

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Kernel Community");
MODULE_DESCRIPTION("Smart Input System - Global accent picker, autocorrect, converters, clipboard history");
MODULE_VERSION("1.0");
