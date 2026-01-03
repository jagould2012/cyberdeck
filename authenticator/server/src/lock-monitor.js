import { spawn } from 'child_process';
import { EventEmitter } from 'events';

/**
 * Monitors system lock screen and idle state
 * Works with common Linux desktop environments
 */
export class LockScreenMonitor extends EventEmitter {
	constructor() {
		super();
		this.dbusMonitor = null;
		this.idleCheckInterval = null;
		this.lastIdleTime = 0;
		this.idleThresholdMs = 300000; // 5 minutes
	}

	async start() {
		// Try to monitor via D-Bus (works with GNOME, KDE, etc.)
		this.startDbusMonitor();

		// Also poll idle time as fallback
		this.startIdleCheck();
	}

	stop() {
		if (this.dbusMonitor) {
			this.dbusMonitor.kill();
			this.dbusMonitor = null;
		}

		if (this.idleCheckInterval) {
			clearInterval(this.idleCheckInterval);
			this.idleCheckInterval = null;
		}
	}

	/**
	 * Monitor D-Bus for screen lock signals
	 */
	startDbusMonitor() {
		try {
			// Monitor screensaver/lock signals
			this.dbusMonitor = spawn('dbus-monitor', [
				'--session',
				"type='signal',interface='org.freedesktop.ScreenSaver'",
				"type='signal',interface='org.gnome.ScreenSaver'",
				"type='signal',interface='org.kde.screensaver'"
			]);

			this.dbusMonitor.stdout.on('data', (data) => {
				const output = data.toString();

				// Check for lock/unlock signals
				if (output.includes('ActiveChanged')) {
					if (output.includes('true')) {
						this.emit('locked');
					} else if (output.includes('false')) {
						this.emit('unlocked');
					}
				}
			});

			this.dbusMonitor.on('error', (error) => {
				console.warn('D-Bus monitor error:', error.message);
			});

			this.dbusMonitor.on('exit', (code) => {
				if (code !== 0) {
					console.warn('D-Bus monitor exited with code:', code);
				}
			});

		} catch (error) {
			console.warn('Could not start D-Bus monitor:', error.message);
		}
	}

	/**
	 * Check idle time periodically
	 */
	startIdleCheck() {
		this.idleCheckInterval = setInterval(async () => {
			try {
				const idleTime = await this.getIdleTime();

				if (idleTime >= this.idleThresholdMs && this.lastIdleTime < this.idleThresholdMs) {
					this.emit('idle');
				} else if (idleTime < this.idleThresholdMs && this.lastIdleTime >= this.idleThresholdMs) {
					this.emit('active');
				}

				this.lastIdleTime = idleTime;
			} catch (error) {
				// Ignore errors, just skip this check
			}
		}, 10000); // Check every 10 seconds
	}

	/**
	 * Get current idle time using xprintidle or xssstate
	 */
	async getIdleTime() {
		return new Promise((resolve, reject) => {
			// Try xprintidle first
			const proc = spawn('xprintidle', []);
			let output = '';

			proc.stdout.on('data', (data) => {
				output += data.toString();
			});

			proc.on('close', (code) => {
				if (code === 0) {
					resolve(parseInt(output.trim(), 10));
				} else {
					// Fallback: assume not idle
					resolve(0);
				}
			});

			proc.on('error', () => {
				resolve(0);
			});
		});
	}

	/**
	 * Check if screen is currently locked
	 */
	async isLocked() {
		return new Promise((resolve) => {
			// Try various methods to detect lock state

			// Method 1: loginctl (systemd)
			const loginctl = spawn('loginctl', ['show-session', '--property=LockedHint']);
			let output = '';

			loginctl.stdout.on('data', (data) => {
				output += data.toString();
			});

			loginctl.on('close', (code) => {
				if (code === 0 && output.includes('LockedHint=yes')) {
					resolve(true);
				} else {
					// Method 2: Check via D-Bus
					this.checkDbusLockState().then(resolve);
				}
			});

			loginctl.on('error', () => {
				this.checkDbusLockState().then(resolve);
			});
		});
	}

	/**
	 * Check lock state via D-Bus
	 */
	async checkDbusLockState() {
		return new Promise((resolve) => {
			const proc = spawn('dbus-send', [
				'--session',
				'--dest=org.freedesktop.ScreenSaver',
				'--type=method_call',
				'--print-reply',
				'/org/freedesktop/ScreenSaver',
				'org.freedesktop.ScreenSaver.GetActive'
			]);

			let output = '';

			proc.stdout.on('data', (data) => {
				output += data.toString();
			});

			proc.on('close', (code) => {
				if (code === 0 && output.includes('true')) {
					resolve(true);
				} else {
					resolve(false);
				}
			});

			proc.on('error', () => {
				resolve(false);
			});
		});
	}
}