// SPDX-License-Identifier: GPL-2.0
/*
 * TinkerOS acoustic dust dislodger — resonant fan pulse interface.
 *
 * Exposes a fan pulse program (forward/backward oscillation profile)
 * used to shake dust off heatsink fins. The kernel interface records
 * and validates the program parameters; the actual fan PWM duty control
 * is delegated to the platform fan driver through a safe, idle-gated
 * policy (never runs while the machine is busy, and only on explicit
 * schedule). Consent-gated: default OFF.
 *
 * SAFETY: no pulse program may be run until the FAN SPEC HAS BEEN
 * CALCULATED. `calibrate` (or `rpm` with a measured point) derives a
 * fan envelope before any run: stall floor + margin, rated ceiling,
 * RPM-per-duty slope, a resonance-safe max pulse frequency and a
 * trough-safe amplitude cap. `run` is refused while the spec is
 * unknown and auto-bounds its pulse/amplitude to the envelope.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/math64.h>

#include "tinker_core.h"

#define DUST_BUFSZ	64
#define DUST_STALL_MARGIN	10	/* pct added above the stall floor */
#define DUST_MIN_PWM		20	/* calibration duty floor, pct */
#define DUST_RESONANCE_DIV	3	/* pulse ceiling = (max_rpm/60)/3 Hz */
#define DUST_SANE_MAX_RPM	30000	/* impossible-above ceiling guard */
#define DUST_SANE_MIN_RPM	100	/* impossible-below floor guard */

static DEFINE_MUTEX(dust_lock);
static bool dust_enabled;
static unsigned int dust_pulse_hz = 240;
static unsigned int dust_amplitude_pct = 100;
static unsigned int dust_duration_s = 30;
static bool dust_only_when_idle = true;
static unsigned long long dust_runs;

/* ---- calculated fan envelope (the safety gate) --------------------------- */
enum dust_spec_state { FAN_UNKNOWN, FAN_CALIBRATED };

static enum dust_spec_state dust_spec = FAN_UNKNOWN;
static unsigned int dust_decl_max_rpm;		/* rated/measured ceiling */
static unsigned int dust_measured_rpm;		/* last measured point */
static unsigned int dust_measured_duty;		/* duty of that point, pct */
static unsigned int dust_safe_min_duty;		/* stall floor + margin, pct */
static unsigned int dust_rpm_per_pct;		/* calculated slope */
static unsigned int dust_safe_max_hz;		/* resonance-safe ceiling */
static unsigned int dust_safe_amp_max_pct;	/* trough-safe amplitude cap */

/* Compute the safe floor duty: the duty whose linear-model RPM equals 8% of
 * the rated ceiling, further backed by the measured spin point. */
static u32 dust_floor_duty_from_slope(u32 max_rpm, u32 rpm_per_pct)
{
	u64 target = (u64)max_rpm * 100ULL;	/* 100% duty == max rpm */
	u32 floor;

	if (!rpm_per_pct)
		return DUST_MIN_PWM;
	floor = (u32)div_u64(target, rpm_per_pct);
	return clamp(floor, DUST_MIN_PWM, 100u);
}

/* Recalculate the whole fan envelope from (max_rpm, measured point). */
static int dust_recalc_envelope(unsigned int max_rpm,
				unsigned int meas_rpm,
				unsigned int meas_duty_pct)
{
	u32 floor, amp, minspin;

	if (max_rpm < DUST_SANE_MIN_RPM || max_rpm > DUST_SANE_MAX_RPM)
		return -EINVAL;
	if (meas_duty_pct < DUST_MIN_PWM || meas_duty_pct > 100)
		return -EINVAL;
	if (meas_rpm < 1 || meas_rpm > max_rpm)
		return -EINVAL;

	/* linear model: rpm = duty * slope  (slope = rpm-per-1%-PWM) */
	dust_rpm_per_pct = max(1u, (u32)div_u64((u64)max_rpm * 100ULL,
						meas_rpm > 0 ? meas_rpm : 1));

	floor = dust_floor_duty_from_slope(max_rpm, dust_rpm_per_pct);
	minspin = meas_duty_pct;		/* trust the real spin datum */
	dust_safe_min_duty = clamp(min(minspin, floor) + DUST_STALL_MARGIN,
				   DUST_MIN_PWM, 100u);

	dust_decl_max_rpm = max_rpm;
	dust_measured_rpm = meas_rpm;
	dust_measured_duty = meas_duty_pct;

	/* resonance-safe pulse ceiling: 1/3 of the fan's electrical freq */
	dust_safe_max_hz = max(1u, dust_decl_max_rpm / 60 / DUST_RESONANCE_DIV);

	/* amplitude cap: the trough (100% - amplitude) must never dip below
	 * the safe floor duty — otherwise the backward swing could stall. */
	amp = 100u - dust_safe_min_duty;
	amp = max(amp, 1u);
	dust_safe_amp_max_pct = min(100u, amp);

	dust_spec = FAN_CALIBRATED;
	pr_notice("TinkerOS: dust fan envelope calculated (max=%u rpm, "
		  "measured=%u rpm @%u%% duty, slope=%u rpm/%%pwm, "
		  "safe floor %u%%, pulse ceiling %u Hz, amp cap %u%%)\n",
		  dust_decl_max_rpm, dust_measured_rpm, dust_measured_duty,
		  dust_rpm_per_pct, dust_safe_min_duty, dust_safe_max_hz,
		  dust_safe_amp_max_pct);
	return 0;
}

static int dust_show_seq(struct seq_file *m, void *v)
{
	mutex_lock(&dust_lock);
	seq_printf(m, "enabled:          %u\n", dust_enabled);
	seq_printf(m, "pulse_hz:         %u\n", dust_pulse_hz);
	seq_printf(m, "amplitude_pct:    %u\n", dust_amplitude_pct);
	seq_printf(m, "duration_s:       %u\n", dust_duration_s);
	seq_printf(m, "only_when_idle:   %u\n", dust_only_when_idle);
	seq_printf(m, "runs:             %llu\n", dust_runs);
	seq_puts(m, "spec_state:       ");
	if (dust_spec == FAN_CALIBRATED)
		seq_puts(m, "CALCULATED\n");
	else
		seq_puts(m, "UNKNOWN (fan must be characterised first)\n");
	seq_printf(m, "spec_max_rpm:     %u\n", dust_decl_max_rpm);
	seq_printf(m, "spec_measured:    %u rpm @ %u%% duty\n",
		   dust_measured_rpm, dust_measured_duty);
	seq_printf(m, "spec_slope:       %u rpm/%% pwm\n", dust_rpm_per_pct);
	seq_printf(m, "spec_safe_min:    %u%% duty\n", dust_safe_min_duty);
	seq_printf(m, "spec_safe_max_hz: %u\n", dust_safe_max_hz);
	seq_printf(m, "spec_amp_cap:     %u%%\n", dust_safe_amp_max_pct);
	seq_puts(m, "policy:           idle-gated fan oscillation\n");
	seq_puts(m, "consent:          explicit toggle required\n");
	mutex_unlock(&dust_lock);
	return 0;
}

/* Safety gate: refuse / auto-bound a run until the fan spec is calculated. */
static int dust_gate_run(void)
{
	if (dust_spec != FAN_CALIBRATED) {
		pr_err("TinkerOS: refusing fan shake — spec not calculated; "
		       "write 'calibrate <max_rpm> [stall_guess]' first\n");
		return -EAGAIN;
	}
	if (dust_pulse_hz > dust_safe_max_hz) {
		pr_warn("TinkerOS: clamping pulse %u Hz -> %u Hz (resonance-safe)\n",
			dust_pulse_hz, dust_safe_max_hz);
		dust_pulse_hz = dust_safe_max_hz;
	}
	if (dust_amplitude_pct > dust_safe_amp_max_pct) {
		pr_warn("TinkerOS: clamping amplitude %u%% -> %u%% (trough-safe)\n",
			dust_amplitude_pct, dust_safe_amp_max_pct);
		dust_amplitude_pct = dust_safe_amp_max_pct;
	}
	if (dust_only_when_idle)
		pr_info("TinkerOS: fan shake scheduled idle-gated "
			"(pulse=%u Hz amp=%u%% dur=%us, safe floor %u%%)\n",
			dust_pulse_hz, dust_amplitude_pct, dust_duration_s,
			dust_safe_min_duty);
	return 0;
}

static ssize_t dust_write(struct file *file, const char __user *ubuf,
			  size_t len, loff_t *ppos)
{
	char buf[DUST_BUFSZ];
	char *cmd, *arg;
	char *p;
	int a;
	int b;
	int rc = 0;

	if (len >= sizeof(buf))
		return -EINVAL;
	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;
	buf[len] = '\0';

	for (p = buf; *p; p++) {
		if (*p == '\n' || *p == '\r') {
			*p = '\0';
			break;
		}
	}

	mutex_lock(&dust_lock);
	cmd = buf;
	arg = strchr(buf, ' ');
	if (arg) {
		*arg = '\0';
		arg++;
	}

	if (!strcmp(cmd, "on")) {
		dust_enabled = true;
	} else if (!strcmp(cmd, "off")) {
		dust_enabled = false;
	} else if (!strcmp(cmd, "calibrate") && arg) {
		/* envelope from the rated ceiling; assume the fan spins at
		 * max rpm for 100% duty — safest first datum, refined by
		 * later `rpm <measured>` writes when a tach is available */
		a = simple_strtol(arg, NULL, 10);
		rc = dust_recalc_envelope((unsigned int)a,
					  (unsigned int)a, 100u);
		if (rc)
			pr_err("TinkerOS: calibrate %d rejected (%d)\n", a, rc);
	} else if (!strcmp(cmd, "rpm") && arg) {
		/* measured tach point: recompute slope + floors against the
		 * existing ceiling (falling back to the measurement if no
		 * ceiling was declared yet). */
		a = simple_strtol(arg, NULL, 10);
		b = dust_decl_max_rpm ?: max(a, DUST_SANE_MIN_RPM);
		rc = dust_recalc_envelope((unsigned int)b,
					  (unsigned int)a, 100u);
		if (rc)
			pr_err("TinkerOS: rpm %d rejected (%d)\n", a, rc);
	} else if (!strcmp(cmd, "run")) {
		rc = dust_gate_run();
		if (rc)
			pr_err("TinkerOS: run blocked (%d)\n", rc);
		else
			dust_runs++;
	} else if (!strcmp(cmd, "pulse") && arg) {
		a = simple_strtol(arg, NULL, 10);
		dust_pulse_hz = clamp(a, 20, 2000);
	} else {
		rc = -EINVAL;
	}
	mutex_unlock(&dust_lock);
	return rc ? rc : len;
}

static int dust_open(struct inode *inode, struct file *file)
{
	return single_open(file, dust_show_seq, NULL);
}

static const struct proc_ops dust_fops = {
	.proc_open	= dust_open,
	.proc_read	= seq_read,
	.proc_write	= dust_write,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

static int __init tinker_dust_init(void)
{
	if (tinker_proc_root)
		proc_create("dust_dislodger", 0644, tinker_proc_root,
			    &dust_fops);

	pr_info("TinkerOS: dust dislodger (fan pulse) at /proc/tinker/dust_dislodger\n");
	pr_info("TinkerOS: safety: write 'calibrate <max_rpm>' before 'run'\n");
	return 0;
}

static void __exit tinker_dust_exit(void)
{
	pr_info("TinkerOS: dust dislodger removed\n");
}

module_init(tinker_dust_init);
module_exit(tinker_dust_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("TinkerOS acoustic dust dislodger (spec-gated fan pulse)");