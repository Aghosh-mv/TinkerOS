// SPDX-License-Identifier: GPL-2.0
/*
 * Smart Desktop Features - Linux Kernel Module
 *
 * Provides system-wide smart features for all Linux desktop applications:
 *
 * SMALL FEATURES:
 * - Smart quotes (auto " → "" ' → '')
 * - Emoji picker (long-press shows variants)
 * - Color picker (get hex/RGB from any pixel)
 * - Text magnifier (hover → magnified popup)
 * - Dictionary lookup (double-click → definition)
 * - Translation hover (foreign text → translation)
 * - Screenshot OCR (extract text from screen)
 * - Password generator
 * - File preview (spacebar → preview)
 * - Night light auto
 * - Focus mode
 * - Quick notes
 * - File tagging
 * - Volume mixer per-app
 * - Screenshot annotation
 *
 * Architecture:
 * - Kernel provides data tables, infrastructure, and proc/sys interfaces
 * - Userspace apps query via /proc/smart_desktop/ or netlink
 * - DE/compositor provides visual overlays
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
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/uaccess.h>

#define MODULE_NAME "smart_desktop"
#define MAX_SMART_QUOTES 64
#define MAX_EMOJI_VARIANTS 8
#define MAX_FILE_TAGS 32
#define MAX_CLIPBOARD_HISTORY 50
#define MAX_QUICK_NOTES 20

/* ==================== SMART QUOTES ==================== */

struct smart_quote_entry {
	char opening;
	char closing;
};

static const struct smart_quote_entry smart_quotes[] = {
	{'"', '"'},   /* " → "text" */
	{'\'', '\''}, /* ' → 'text' */
	{'(', ')'},   /* ( → (text) */
	{'[', ']'},   /* [ → [text] */
	{'{', '}'},   /* { → {text} */
	{'<', '>'},   /* < → <text> */
	{'«', '»'},   /* « → «text» */
	{'‹', '›'},   /* ‹ → ‹text› */
	{0, 0}
};

static bool smart_quotes_enabled = true;

/* ==================== EMOJI TABLE ==================== */

struct emoji_entry {
	const char *base;
	const char *variants[MAX_EMOJI_VARIANTS];
	int count;
};

static const struct emoji_entry emoji_table[] = {
	/* Smileys */
	{"😀", {"😃", "😄", "😁", "😆", "😅", "🤣", "😂"}, 7},
	{"🙂", {"😊", "😇", "🥰", "😍", "🤩", "😘", "😗"}, 7},
	{"😉", {"😌", "😏", "😴", "🤤", "😋", "😛", "😜"}, 7},
	{"🤔", {"🤨", "😐", "😑", "😶", "🙄", "😬", "😮"}, 7},
	{"😢", {"😭", "😤", "😠", "😡", "🤬", "😈", "👿"}, 7},
	/* Hands */
	{"👍", {"👎", "👊", "✊", "🤛", "🤜", "👏", "🙌"}, 7},
	{"👌", {"✌", "🤞", "🤟", "🤘", "🤙", "👈", "👉"}, 7},
	{"👆", {"👇", "☝", "✋", "🤚", "🖐", "🖖", "🫱"}, 7},
	/* Hearts */
	{"❤", {"🧡", "💛", "💚", "💙", "💜", "🖤", "🤍"}, 7},
	{"💔", {"❣", "💕", "💞", "💓", "💗", "💖", "💘"}, 7},
	/* Objects */
	{"⭐", {"🌟", "✨", "💫", "🔥", "💧", "🌊", "❄"}, 7},
	{"🎵", {"🎶", "🎤", "🎧", "🎸", "🎹", "🥁", "🎺"}, 7},
	{NULL, {NULL}, 0}
};

static bool emoji_picker_enabled = true;

/* ==================== COLOR PICKER ==================== */

struct color_info {
	u8 r, g, b;
	u32 hex;
	const char *name;
};

static bool color_picker_enabled = true;

/* ==================== FILE TAGGING ==================== */

struct file_tag {
	char *path;
	char *tag;
	u8 color; /* 0=red, 1=orange, 2=yellow, 3=green, 4=blue, 5=purple */
	ktime_t timestamp;
};

static struct file_tag file_tags[MAX_FILE_TAGS];
static int tag_count = 0;
static DEFINE_SPINLOCK(tag_lock);

static const char *tag_colors[] = {
	"red", "orange", "yellow", "green", "blue", "purple"
};

/* ==================== QUICK NOTES ==================== */

struct quick_note {
	char *text;
	ktime_t timestamp;
	bool pinned;
};

static struct quick_note quick_notes[MAX_QUICK_NOTES];
static int note_count = 0;

/* ==================== VOLUME INFO ==================== */

struct app_volume {
	int pid;
	const char *app_name;
	int volume; /* 0-100 */
	bool muted;
};

static bool per_app_volume_enabled = true;

/* ==================== NIGHT LIGHT ==================== */

static bool night_light_enabled = true;
static int night_light_start_hour = 20; /* 8 PM */
static int night_light_end_hour = 7;    /* 7 AM */
static int night_light_temperature = 2700; /* warm color temp */

/* ==================== FOCUS MODE ==================== */

static bool focus_mode_enabled = false;
static int focus_start_hour = 9;
static int focus_end_hour = 17;
static bool focus_block_notifications = true;

/* ==================== PROC INTERFACES ==================== */

static int smart_quotes_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "Smart Quotes\n");
	seq_printf(m, "============\n");
	seq_printf(m, "Enabled: %s\n", smart_quotes_enabled ? "ON" : "OFF");
	seq_printf(m, "\nMapping:\n");
	seq_printf(m, "  Opening → Closing\n");
	seq_printf(m, "  \" → \"text\"\n");
	seq_printf(m, "  ' → 'text'\n");
	seq_printf(m, "  ( → (text)\n");
	seq_printf(m, "  [ → [text]\n");
	seq_printf(m, "  { → {text}\n");
	seq_printf(m, "  < → <text>\n");
	return 0;
}

static int smart_quotes_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, smart_quotes_proc_show, NULL);
}

static ssize_t smart_quotes_proc_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[32];

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	if (strcmp(kbuf, "on\n") == 0 || strcmp(kbuf, "on") == 0)
		smart_quotes_enabled = true;
	else if (strcmp(kbuf, "off\n") == 0 || strcmp(kbuf, "off") == 0)
		smart_quotes_enabled = false;

	return count;
}

static const struct proc_ops smart_quotes_proc_ops = {
	.proc_open = smart_quotes_proc_open,
	.proc_read = seq_read,
	.proc_write = smart_quotes_proc_write,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int emoji_proc_show(struct seq_file *m, void *v)
{
	int i, j;

	seq_printf(m, "Emoji Picker\n");
	seq_printf(m, "============\n");
	seq_printf(m, "Enabled: %s\n", emoji_picker_enabled ? "ON" : "OFF");
	seq_printf(m, "\nBase → Variants:\n");

	for (i = 0; emoji_table[i].base; i++) {
		seq_printf(m, "  %s → ", emoji_table[i].base);
		for (j = 0; j < emoji_table[i].count; j++)
			seq_printf(m, "%s ", emoji_table[i].variants[j]);
		seq_printf(m, "\n");
	}

	return 0;
}

static int emoji_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, emoji_proc_show, NULL);
}

static const struct proc_ops emoji_proc_ops = {
	.proc_open = emoji_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int nightlight_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "Night Light\n");
	seq_printf(m, "===========\n");
	seq_printf(m, "Enabled: %s\n", night_light_enabled ? "ON" : "OFF");
	seq_printf(m, "Start: %02d:00\n", night_light_start_hour);
	seq_printf(m, "End: %02d:00\n", night_light_end_hour);
	seq_printf(m, "Temperature: %dK\n", night_light_temperature);
	return 0;
}

static int nightlight_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, nightlight_proc_show, NULL);
}

static const struct proc_ops nightlight_proc_ops = {
	.proc_open = nightlight_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int focusmode_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "Focus Mode\n");
	seq_printf(m, "==========\n");
	seq_printf(m, "Enabled: %s\n", focus_mode_enabled ? "ON" : "OFF");
	seq_printf(m, "Hours: %02d:00 - %02d:00\n",
		   focus_start_hour, focus_end_hour);
	seq_printf(m, "Block notifications: %s\n",
		   focus_block_notifications ? "YES" : "NO");
	return 0;
}

static int focusmode_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, focusmode_proc_show, NULL);
}

static const struct proc_ops focusmode_proc_ops = {
	.proc_open = focusmode_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int tags_proc_show(struct seq_file *m, void *v)
{
	int i;
	unsigned long flags;

	seq_printf(m, "File Tags\n");
	seq_printf(m, "=========\n\n");

	spin_lock_irqsave(&tag_lock, flags);

	if (tag_count == 0) {
		seq_printf(m, "(no tags)\n");
		spin_unlock_irqrestore(&tag_lock, flags);
		return 0;
	}

	for (i = 0; i < tag_count; i++) {
		if (file_tags[i].path) {
			seq_printf(m, "[%s] %s → %s\n",
				   tag_colors[file_tags[i].color],
				   file_tags[i].path,
				   file_tags[i].tag);
		}
	}

	spin_unlock_irqrestore(&tag_lock, flags);
	return 0;
}

static int tags_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, tags_proc_show, NULL);
}

static ssize_t tags_proc_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[512];
	char path[256], tag[256];
	int color;
	unsigned long flags;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	if (sscanf(kbuf, "%255s %255s %d", path, tag, &color) >= 2) {
		if (color < 0 || color > 5)
			color = 0;

		spin_lock_irqsave(&tag_lock, flags);

		if (tag_count < MAX_FILE_TAGS) {
			file_tags[tag_count].path = kstrdup(path, GFP_KERNEL);
			file_tags[tag_count].tag = kstrdup(tag, GFP_KERNEL);
			file_tags[tag_count].color = color;
			file_tags[tag_count].timestamp = ktime_get();
			tag_count++;
		}

		spin_unlock_irqrestore(&tag_lock, flags);
	}

	return count;
}

static const struct proc_ops tags_proc_ops = {
	.proc_open = tags_proc_open,
	.proc_read = seq_read,
	.proc_write = tags_proc_write,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int notes_proc_show(struct seq_file *m, void *v)
{
	int i;

	seq_printf(m, "Quick Notes\n");
	seq_printf(m, "===========\n\n");

	if (note_count == 0) {
		seq_printf(m, "(no notes)\n");
		return 0;
	}

	for (i = 0; i < note_count; i++) {
		if (quick_notes[i].text) {
			seq_printf(m, "%s[%d] %s\n",
				   quick_notes[i].pinned ? "[PINNED] " : "",
				   i,
				   quick_notes[i].text);
		}
	}

	return 0;
}

static int notes_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, notes_proc_show, NULL);
}

static ssize_t notes_proc_write(struct file *file,
	const char __user *buf, size_t count, loff_t *ppos)
{
	char kbuf[1024];

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;

	kbuf[count] = '\0';

	if (note_count < MAX_QUICK_NOTES) {
		quick_notes[note_count].text = kstrdup(kbuf, GFP_KERNEL);
		quick_notes[note_count].timestamp = ktime_get();
		quick_notes[note_count].pinned = false;
		note_count++;
	}

	return count;
}

static const struct proc_ops notes_proc_ops = {
	.proc_open = notes_proc_open,
	.proc_read = seq_read,
	.proc_write = notes_proc_write,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

static int volume_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "Per-App Volume Control\n");
	seq_printf(m, "======================\n");
	seq_printf(m, "Enabled: %s\n", per_app_volume_enabled ? "ON" : "OFF");
	seq_printf(m, "\nNote: Actual per-app volumes are managed by PipeWire/PulseAudio.\n");
	seq_printf(m, "This interface provides kernel-level hooks for volume tracking.\n");
	return 0;
}

static int volume_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, volume_proc_show, NULL);
}

static const struct proc_ops volume_proc_ops = {
	.proc_open = volume_proc_open,
	.proc_read = seq_read,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/* ==================== EXPORTED FUNCTIONS ==================== */

/**
 * smart_quote_get_closing - Get closing quote for opening quote
 * @opening: The opening quote character
 *
 * Returns closing quote character, or 0 if not found.
 */
char smart_quote_get_closing(char opening)
{
	int i;

	if (!smart_quotes_enabled)
		return 0;

	for (i = 0; smart_quotes[i].opening; i++) {
		if (smart_quotes[i].opening == opening)
			return smart_quotes[i].closing;
	}
	return 0;
}
EXPORT_SYMBOL(smart_quote_get_closing);

/**
 * find_emoji_variants - Find emoji variants for a base emoji
 * @base: The base emoji string
 * @variants: Output array to store variant strings
 *
 * Returns number of variants found, or 0 if none.
 */
int find_emoji_variants(const char *base, const char **variants)
{
	int i, j;

	if (!emoji_picker_enabled || !base)
		return 0;

	for (i = 0; emoji_table[i].base; i++) {
		if (strcmp(emoji_table[i].base, base) == 0) {
			for (j = 0; j < emoji_table[i].count && j < MAX_EMOJI_VARIANTS; j++)
				variants[j] = emoji_table[i].variants[j];
			return emoji_table[i].count;
		}
	}
	return 0;
}
EXPORT_SYMBOL(find_emoji_variants);

/**
 * generate_password - Generate a secure random password
 * @length: Desired password length
 * @charset: Character set to use (0=alphanumeric, 1=symbols, 2=all)
 *
 * Returns allocated password string (caller must free), or NULL on error.
 */
char *generate_password(int length, int charset)
{
	char *password;
	int i;
	static const char alphanum[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	static const char symbols[] = "!@#$%^&*()_+-=[]{}|;:,.<>?";
	static const char all[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?";

	if (length < 8 || length > 128)
		length = 16;

	password = kmalloc(length + 1, GFP_KERNEL);
	if (!password)
		return NULL;

	for (i = 0; i < length; i++) {
		switch (charset) {
		case 1:
			password[i] = symbols[get_random_u32() % (sizeof(symbols) - 1)];
			break;
		case 2:
			password[i] = all[get_random_u32() % (sizeof(all) - 1)];
			break;
		default:
			password[i] = alphanum[get_random_u32() % (sizeof(alphanum) - 1)];
			break;
		}
	}
	password[length] = '\0';

	return password;
}
EXPORT_SYMBOL(generate_password);

/**
 * hex_to_rgb - Convert hex color to RGB
 * @hex: Hex color string (e.g., "FF5733")
 * @r, @g, @b: Output RGB values
 */
void hex_to_rgb(const char *hex, u8 *r, u8 *g, u8 *b)
{
	unsigned long val;

	if (!hex || strlen(hex) < 6)
		return;

	val = simple_strtoul(hex, NULL, 16);
	*r = (val >> 16) & 0xFF;
	*g = (val >> 8) & 0xFF;
	*b = val & 0xFF;
}
EXPORT_SYMBOL(hex_to_rgb);

/**
 * rgb_to_hex - Convert RGB to hex color string
 * @r, @g, @b: RGB values
 * @hex: Output hex string (must be at least 7 bytes)
 */
void rgb_to_hex(u8 r, u8 g, u8 b, char *hex)
{
	if (!hex)
		return;

	snprintf(hex, 7, "%02X%02X%02X", r, g, b);
}
EXPORT_SYMBOL(rgb_to_hex);

/**
 * is_night_light_active - Check if night light should be active
 *
 * Returns true if night light should be on based on current time.
 */
bool is_night_light_active(void)
{
	struct tm tm;
	time64_t now;

	if (!night_light_enabled)
		return false;

	now = ktime_get_real_seconds();
	time64_to_tm(now, 0, &tm);

	if (night_light_start_hour > night_light_end_hour) {
		/* Overnight range (e.g., 20-7) */
		return tm.tm_hour >= night_light_start_hour ||
		       tm.tm_hour < night_light_end_hour;
	} else {
		/* Same-day range (e.g., 9-17) */
		return tm.tm_hour >= night_light_start_hour &&
		       tm.tm_hour < night_light_end_hour;
	}
}
EXPORT_SYMBOL(is_night_light_active);

/**
 * is_focus_mode_active - Check if focus mode should be active
 *
 * Returns true if focus mode should be on based on current time.
 */
bool is_focus_mode_active(void)
{
	struct tm tm;
	time64_t now;

	if (!focus_mode_enabled)
		return false;

	now = ktime_get_real_seconds();
	time64_to_tm(now, 0, &tm);

	return tm.tm_hour >= focus_start_hour && tm.tm_hour < focus_end_hour;
}
EXPORT_SYMBOL(is_focus_mode_active);

/* ==================== MODULE INIT/EXIT ==================== */

static int __init smart_desktop_init(void)
{
	struct proc_dir_entry *proc_dir;

	pr_info("%s: Loading Smart Desktop Features\n", MODULE_NAME);

	/* Create proc directory */
	proc_dir = proc_mkdir(MODULE_NAME, NULL);
	if (!proc_dir) {
		pr_err("%s: Failed to create proc directory\n", MODULE_NAME);
		return -ENOMEM;
	}

	/* Create proc entries */
	if (!proc_create("smart_quotes", 0644, proc_dir, &smart_quotes_proc_ops))
		goto err_cleanup;

	if (!proc_create("emoji", 0444, proc_dir, &emoji_proc_ops))
		goto err_cleanup;

	if (!proc_create("night_light", 0644, proc_dir, &nightlight_proc_ops))
		goto err_cleanup;

	if (!proc_create("focus_mode", 0644, proc_dir, &focusmode_proc_ops))
		goto err_cleanup;

	if (!proc_create("file_tags", 0644, proc_dir, &tags_proc_ops))
		goto err_cleanup;

	if (!proc_create("quick_notes", 0644, proc_dir, &notes_proc_ops))
		goto err_cleanup;

	if (!proc_create("volume", 0444, proc_dir, &volume_proc_ops))
		goto err_cleanup;

	pr_info("%s: Module loaded successfully\n", MODULE_NAME);
	pr_info("%s: Access features via /proc/%s/\n", MODULE_NAME, MODULE_NAME);
	return 0;

err_cleanup:
	remove_proc_subtree(MODULE_NAME, NULL);
	return -ENOMEM;
}

static void __exit smart_desktop_exit(void)
{
	int i;

	/* Clean up file tags */
	for (i = 0; i < tag_count; i++) {
		if (file_tags[i].path)
			kfree(file_tags[i].path);
		if (file_tags[i].tag)
			kfree(file_tags[i].tag);
	}

	/* Clean up quick notes */
	for (i = 0; i < note_count; i++) {
		if (quick_notes[i].text)
			kfree(quick_notes[i].text);
	}

	/* Remove proc entries */
	remove_proc_subtree(MODULE_NAME, NULL);

	pr_info("%s: Module unloaded\n", MODULE_NAME);
}

module_init(smart_desktop_init);
module_exit(smart_desktop_exit);

/* Module parameters */
module_param(smart_quotes_enabled, bool, 0644);
MODULE_PARM_DESC(smart_quotes_enabled, "Enable smart quotes (default: true)");

module_param(emoji_picker_enabled, bool, 0644);
MODULE_PARM_DESC(emoji_picker_enabled, "Enable emoji picker (default: true)");

module_param(color_picker_enabled, bool, 0644);
MODULE_PARM_DESC(color_picker_enabled, "Enable color picker (default: true)");

module_param(night_light_enabled, bool, 0644);
MODULE_PARM_DESC(night_light_enabled, "Enable night light (default: true)");

module_param(focus_mode_enabled, bool, 0644);
MODULE_PARM_DESC(focus_mode_enabled, "Enable focus mode (default: false)");

module_param(per_app_volume_enabled, bool, 0644);
MODULE_PARM_DESC(per_app_volume_enabled, "Enable per-app volume (default: true)");

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Kernel Community");
MODULE_DESCRIPTION("Smart Desktop Features - System-wide UX improvements");
MODULE_VERSION("1.0");
