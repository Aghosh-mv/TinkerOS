// SPDX-License-Identifier: GPL-2.0
/*
 * KorrinOS Desktop Environment — kernel-level desktop state
 * Provides /proc/tinker/desktop interface
 * Tracks panel, dock, themes, workspaces, windows, accessibility, monitors
 */

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/ktime.h>
#include <linux/slab.h>
#include <linux/mutex.h>

#define DESKTOP_MAX_WORKSPACES 16
#define DESKTOP_MAX_MONITORS   8
#define DESKTOP_NAME_MAX       64
#define DESKTOP_THEME_MAX      128

enum compositor_backend {
	COMP_NONE = 0,
	COMP_PICOM,
	COMP_COMPTON,
	COMP_MUTTER,
	COMP_KWIN
};

struct monitor_info {
	char name[DESKTOP_NAME_MAX];
	int width;
	int height;
	int refresh_rate;
	int primary;
	int active;
};

struct workspace_info {
	int id;
	char name[DESKTOP_NAME_MAX];
	int active;
	int window_count;
};

struct desktop_state {
	/* Panel */
	int panel_visible;
	int panel_position;
	int panel_height;
	int panel_autohide;

	/* Dock */
	int dock_visible;
	int dock_position;
	int dock_size;
	int dock_autohide;
	int dock_items;

	/* Theme */
	char theme_name[DESKTOP_THEME_MAX];
	char icon_theme[DESKTOP_THEME_MAX];
	char cursor_theme[DESKTOP_THEME_MAX];
	char wallpaper[512];
	int dark_mode;
	int accent_color;

	/* Compositor */
	enum compositor_backend compositor;
	int compositor_active;
	int blur_enabled;
	int transparency_enabled;
	int shadows_enabled;
	int vsync_enabled;

	/* Workspaces */
	struct workspace_info workspaces[DESKTOP_MAX_WORKSPACES];
	int workspace_count;
	int active_workspace;

	/* Monitors */
	struct monitor_info monitors[DESKTOP_MAX_MONITORS];
	int monitor_count;

	/* Accessibility */
	int high_contrast;
	int large_text;
	int screen_reader;
	int sticky_keys;
	int slow_keys;
	int mouse_keys;

	/* System */
	int windows_open;
	int apps_running;
	ktime_t session_start;
	struct mutex lock;
};

static struct proc_dir_entry *desktop_proc_entry;
static struct desktop_state *desk_st;

static const char *compositor_str(enum compositor_backend c)
{
	switch (c) {
	case COMP_NONE:    return "none";
	case COMP_PICOM:   return "picom";
	case COMP_COMPTON: return "compton";
	case COMP_MUTTER:  return "mutter";
	case COMP_KWIN:    return "kwin";
	default:           return "unknown";
	}
}

static int desktop_show(struct seq_file *m, void *v)
{
	int i;
	unsigned long uptime_s;

	if (!desk_st)
		return 0;

	uptime_s = ktime_get_real_seconds() -
		   (desk_st->session_start ? ktime_to_timespec(desk_st->session_start).tv_sec : 0);

	seq_printf(m, "=== KorrinOS Desktop State ===\n\n");

	seq_printf(m, "Panel:     %s height=%d autohide=%s\n",
		   desk_st->panel_visible ? "visible" : "hidden",
		   desk_st->panel_height,
		   desk_st->panel_autohide ? "on" : "off");

	seq_printf(m, "Dock:      %s items=%d size=%d autohide=%s\n",
		   desk_st->dock_visible ? "visible" : "hidden",
		   desk_st->dock_items, desk_st->dock_size,
		   desk_st->dock_autohide ? "on" : "off");

	seq_printf(m, "\nTheme:\n");
	seq_printf(m, "  Name:     %s\n", desk_st->theme_name);
	seq_printf(m, "  Icons:    %s\n", desk_st->icon_theme);
	seq_printf(m, "  Cursor:   %s\n", desk_st->cursor_theme);
	seq_printf(m, "  Dark:     %s\n", desk_st->dark_mode ? "yes" : "no");
	seq_printf(m, "  Wallpaper: %s\n",
		   desk_st->wallpaper[0] ? desk_st->wallpaper : "(default)");

	seq_printf(m, "\nCompositor: %s %s\n",
		   compositor_str(desk_st->compositor),
		   desk_st->compositor_active ? "(active)" : "(inactive)");
	seq_printf(m, "  Blur:         %s\n", desk_st->blur_enabled ? "on" : "off");
	seq_printf(m, "  Transparency: %s\n", desk_st->transparency_enabled ? "on" : "off");
	seq_printf(m, "  Shadows:      %s\n", desk_st->shadows_enabled ? "on" : "off");
	seq_printf(m, "  VSync:        %s\n", desk_st->vsync_enabled ? "on" : "off");

	seq_printf(m, "\nWorkspaces: %d active=%d\n",
		   desk_st->workspace_count, desk_st->active_workspace);
	for (i = 0; i < desk_st->workspace_count; i++) {
		seq_printf(m, "  [%d] %-15s windows=%d%s\n",
			   desk_st->workspaces[i].id,
			   desk_st->workspaces[i].name,
			   desk_st->workspaces[i].window_count,
			   desk_st->workspaces[i].active ? " *" : "");
	}

	seq_printf(m, "\nMonitors: %d\n", desk_st->monitor_count);
	for (i = 0; i < desk_st->monitor_count; i++) {
		seq_printf(m, "  %-12s %dx%d@%dHz %s\n",
			   desk_st->monitors[i].name,
			   desk_st->monitors[i].width,
			   desk_st->monitors[i].height,
			   desk_st->monitors[i].refresh_rate,
			   desk_st->monitors[i].primary ? "(primary)" : "");
	}

	seq_printf(m, "\nAccessibility:\n");
	seq_printf(m, "  High contrast:  %s\n", desk_st->high_contrast ? "on" : "off");
	seq_printf(m, "  Large text:     %s\n", desk_st->large_text ? "on" : "off");
	seq_printf(m, "  Screen reader:  %s\n", desk_st->screen_reader ? "on" : "off");
	seq_printf(m, "  Sticky keys:    %s\n", desk_st->sticky_keys ? "on" : "off");

	seq_printf(m, "\nSystem:\n");
	seq_printf(m, "  Windows open:   %d\n", desk_st->windows_open);
	seq_printf(m, "  Apps running:   %d\n", desk_st->apps_running);
	seq_printf(m, "  Session uptime: %lus\n", uptime_s);

	return 0;
}

static int desktop_open(struct inode *inode, struct file *file)
{
	return single_open(file, desktop_show, NULL);
}

static ssize_t desktop_write(struct file *file, const char __user *buf,
			     size_t count, loff_t *ppos)
{
	char kbuf[512];
	char cmd[32], arg1[DESKTOP_NAME_MAX], arg2[128];
	int ret;

	if (count >= sizeof(kbuf))
		return -EINVAL;

	if (copy_from_user(kbuf, buf, count))
		return -EFAULT;
	kbuf[count] = '\0';

	mutex_lock(&desk_st->lock);

	ret = sscanf(kbuf, "%31s %63s %127s", cmd, arg1, arg2);

	if (strcmp(cmd, "panel-show") == 0) {
		desk_st->panel_visible = 1;
	} else if (strcmp(cmd, "panel-hide") == 0) {
		desk_st->panel_visible = 0;
	} else if (strcmp(cmd, "panel-height") == 0 && ret >= 2) {
		desk_st->panel_height = simple_strtoul(arg1, NULL, 10);
	} else if (strcmp(cmd, "panel-autohide") == 0 && ret >= 2) {
		desk_st->panel_autohide = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "dock-show") == 0) {
		desk_st->dock_visible = 1;
	} else if (strcmp(cmd, "dock-hide") == 0) {
		desk_st->dock_visible = 0;
	} else if (strcmp(cmd, "dock-items") == 0 && ret >= 2) {
		desk_st->dock_items = simple_strtoul(arg1, NULL, 10);
	} else if (strcmp(cmd, "theme") == 0 && ret >= 2) {
		strscpy(desk_st->theme_name, arg1, DESKTOP_THEME_MAX);
	} else if (strcmp(cmd, "icons") == 0 && ret >= 2) {
		strscpy(desk_st->icon_theme, arg1, DESKTOP_THEME_MAX);
	} else if (strcmp(cmd, "wallpaper") == 0 && ret >= 2) {
		sscanf(kbuf, "%*s %511[^\n]", desk_st->wallpaper);
	} else if (strcmp(cmd, "dark") == 0 && ret >= 2) {
		desk_st->dark_mode = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "compositor") == 0 && ret >= 2) {
		if (strcmp(arg1, "picom") == 0)
			desk_st->compositor = COMP_PICOM;
		else if (strcmp(arg1, "mutter") == 0)
			desk_st->compositor = COMP_MUTTER;
		else if (strcmp(arg1, "kwin") == 0)
			desk_st->compositor = COMP_KWIN;
		else
			desk_st->compositor = COMP_NONE;
		desk_st->compositor_active = (desk_st->compositor != COMP_NONE);
	} else if (strcmp(cmd, "blur") == 0 && ret >= 2) {
		desk_st->blur_enabled = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "transparency") == 0 && ret >= 2) {
		desk_st->transparency_enabled = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "workspace-add") == 0 && ret >= 2) {
		if (desk_st->workspace_count < DESKTOP_MAX_WORKSPACES) {
			int idx = desk_st->workspace_count;
			desk_st->workspaces[idx].id = idx + 1;
			strscpy(desk_st->workspaces[idx].name, arg1, DESKTOP_NAME_MAX);
			desk_st->workspace_count++;
		}
	} else if (strcmp(cmd, "workspace-switch") == 0 && ret >= 2) {
		int ws = simple_strtoul(arg1, NULL, 10);
		int j;
		for (j = 0; j < desk_st->workspace_count; j++) {
			desk_st->workspaces[j].active =
				(desk_st->workspaces[j].id == ws);
		}
		desk_st->active_workspace = ws;
	} else if (strcmp(cmd, "monitor-add") == 0 && ret >= 3) {
		if (desk_st->monitor_count < DESKTOP_MAX_MONITORS) {
			struct monitor_info *mi =
				&desk_st->monitors[desk_st->monitor_count++];
			strscpy(mi->name, arg1, DESKTOP_NAME_MAX);
			sscanf(arg2, "%dx%d", &mi->width, &mi->height);
			mi->refresh_rate = 60;
			mi->active = 1;
		}
	} else if (strcmp(cmd, "windows") == 0 && ret >= 2) {
		desk_st->windows_open = simple_strtoul(arg1, NULL, 10);
	} else if (strcmp(cmd, "apps") == 0 && ret >= 2) {
		desk_st->apps_running = simple_strtoul(arg1, NULL, 10);
	} else if (strcmp(cmd, "high-contrast") == 0 && ret >= 2) {
		desk_st->high_contrast = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "large-text") == 0 && ret >= 2) {
		desk_st->large_text = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "screen-reader") == 0 && ret >= 2) {
		desk_st->screen_reader = (strcmp(arg1, "on") == 0);
	} else if (strcmp(cmd, "session-start") == 0) {
		desk_st->session_start = ktime_get_real();
	} else {
		mutex_unlock(&desk_st->lock);
		return -EINVAL;
	}

	mutex_unlock(&desk_st->lock);
	return count;
}

static const struct proc_ops desktop_proc_ops = {
	.proc_open    = desktop_open,
	.proc_write   = desktop_write,
	.proc_read    = seq_read,
	.proc_lseek   = seq_lseek,
	.proc_release = single_release,
};

static int __init desktop_init(void)
{
	desk_st = kzalloc(sizeof(*desk_st), GFP_KERNEL);
	if (!desk_st)
		return -ENOMEM;

	mutex_init(&desk_st->lock);

	/* Defaults */
	desk_st->panel_visible = 1;
	desk_st->panel_height = 32;
	desk_st->dock_visible = 1;
	desk_st->dock_size = 48;
	desk_st->dark_mode = 0;
	desk_st->compositor = COMP_PICOM;
	desk_st->blur_enabled = 1;
	desk_st->transparency_enabled = 1;
	desk_st->shadows_enabled = 1;
	desk_st->vsync_enabled = 1;
	desk_st->session_start = ktime_get_real();

	/* Default workspace */
	desk_st->workspace_count = 1;
	desk_st->workspaces[0].id = 1;
	strscpy(desk_st->workspaces[0].name, "Desktop", DESKTOP_NAME_MAX);
	desk_st->workspaces[0].active = 1;
	desk_st->active_workspace = 1;

	desktop_proc_entry = proc_create("tinker/desktop", 0644, NULL,
					 &desktop_proc_ops);
	if (!desktop_proc_entry) {
		kfree(desk_st);
		return -ENOMEM;
	}

	pr_info("KorrinOS: desktop state loaded\n");
	return 0;
}

static void __exit desktop_exit(void)
{
	proc_remove(desktop_proc_entry);
	kfree(desk_st);
	pr_info("KorrinOS: desktop state unloaded\n");
}

module_init(desktop_init);
module_exit(desktop_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("KorrinOS");
MODULE_DESCRIPTION("KorrinOS kernel desktop environment state");
MODULE_VERSION("1.0");
