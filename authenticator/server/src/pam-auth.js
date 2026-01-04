import { spawn, execSync } from 'child_process';
import { writeFile, unlink } from 'fs/promises';

/**
 * Handles PAM-based login without password
 * Requires the cyberdeck-login PAM module to be installed
 */
export class PamAuth {
	constructor(loginUser) {
		this.loginUser = loginUser;
		this.triggerFile = '/tmp/cyberdeck-login-trigger';
		// Check if running in container (PID 1 is not init)
		this.inContainer = this.detectContainer();
		if (this.inContainer) {
			console.log('🐳 Running in container, using nsenter for host commands');
		}
	}

	detectContainer() {
		// Check for CONTAINER_MODE env var set in docker-compose
		return process.env.CONTAINER_MODE === 'true';
	}

	/**
	 * Run a command, using nsenter if in container to access host
	 */
	hostSpawn(cmd, args) {
		if (this.inContainer) {
			// Use nsenter to run in host namespaces (requires --pid=host and --privileged)
			return spawn('nsenter', ['-t', '1', '-m', '-u', '-i', '-n', cmd, ...args]);
		}
		return spawn(cmd, args);
	}

	/**
	 * Trigger login for the configured user
	 * This creates a trigger file that the PAM module watches for
	 */
	async triggerLogin() {
		console.log(`🔓 Triggering PAM login for user: ${this.loginUser}`);

		try {
			// Method 1: Try to unlock via loginctl (systemd)
			await this.unlockViaLoginctl();

			// Method 2: Try to unlock via D-Bus screensavers
			await this.unlockViaDbus();

			// Method 3: Wake screen, write trigger file, and auto-submit
			await this.autoSubmitLogin();

		} catch (error) {
			console.error('Failed to trigger login:', error);
			throw error;
		}
	}

	/**
	 * Write trigger file that PAM module monitors
	 */
	async writeTriggerFile() {
		const triggerData = {
			user: this.loginUser,
			timestamp: Date.now(),
			action: 'unlock'
		};

		await writeFile(this.triggerFile, JSON.stringify(triggerData), {
			mode: 0o666
		});
	}

	/**
	 * Try to unlock session via loginctl
	 */
	async unlockViaLoginctl() {
		// First try generic unlock-sessions
		await this.tryCommand('/usr/bin/loginctl', ['unlock-sessions']);

		// Also try to unlock specific sessions for this user
		try {
			let output;
			if (this.inContainer) {
				output = execSync('nsenter -t 1 -m -u -i -n /usr/bin/loginctl list-sessions --no-legend', { encoding: 'utf-8' });
			} else {
				output = execSync('loginctl list-sessions --no-legend', { encoding: 'utf-8' });
			}
			const lines = output.trim().split('\n');

			for (const line of lines) {
				const parts = line.trim().split(/\s+/);
				if (parts.length >= 3) {
					const sessionId = parts[0];
					const user = parts[2];
					if (user === this.loginUser) {
						await this.tryCommand('/usr/bin/loginctl', ['unlock-session', sessionId]);
					}
				}
			}
		} catch (err) {
			// Ignore errors
		}
	}

	/**
	 * Try to unlock via D-Bus screensaver interface
	 */
	async unlockViaDbus() {
		// Try GNOME screensaver
		await this.tryCommand('/usr/bin/dbus-send', [
			'--session',
			'--type=method_call',
			'--dest=org.gnome.ScreenSaver',
			'/org/gnome/ScreenSaver',
			'org.gnome.ScreenSaver.SetActive',
			'boolean:false'
		]);

		// Try freedesktop screensaver
		await this.tryCommand('/usr/bin/dbus-send', [
			'--session',
			'--type=method_call',
			'--dest=org.freedesktop.ScreenSaver',
			'/org/freedesktop/ScreenSaver',
			'org.freedesktop.ScreenSaver.SetActive',
			'boolean:false'
		]);

		// Try KDE screensaver
		await this.tryCommand('/usr/bin/dbus-send', [
			'--session',
			'--type=method_call',
			'--dest=org.kde.screensaver',
			'/ScreenSaver',
			'org.freedesktop.ScreenSaver.SetActive',
			'boolean:false'
		]);

		// Try xscreensaver
		await this.tryCommand('/usr/bin/xscreensaver-command', ['-deactivate']);

		// Try light-locker
		await this.tryCommand('/usr/bin/light-locker-command', ['-l']);

		// Try cinnamon screensaver
		await this.tryCommand('/usr/bin/cinnamon-screensaver-command', ['-d']);

		// Try mate screensaver  
		await this.tryCommand('/usr/bin/mate-screensaver-command', ['-d']);

		// Try xdotool to simulate activity (fallback)
		await this.tryCommand('/usr/bin/xdotool', ['key', 'shift']);
	}

	/**
	 * Helper to try a command without failing (silent)
	 */
	async tryCommand(cmd, args) {
		return new Promise((resolve) => {
			const proc = this.hostSpawn(cmd, args);
			proc.on('close', () => resolve());
			proc.on('error', () => resolve());
		});
	}

	/**
	 * Auto-submit login on the greeter
	/**
	 * Auto-submit login on the greeter
	 * Key insight: trigger file must exist BEFORE greeter calls PAM
	 * Sequence: write trigger -> restart greeter -> wait -> submit
	 */
	async autoSubmitLogin() {
		// Step 1: Write trigger file FIRST
		await this.writeTriggerFile();

		// Step 2: Sync to ensure file is on disk
		await new Promise((resolve) => {
			const proc = this.hostSpawn('sync', []);
			proc.on('close', () => resolve());
			proc.on('error', () => resolve());
		});

		// Step 3: Small delay to ensure file is visible
		await new Promise(resolve => setTimeout(resolve, 200));

		// Step 4: Find and terminate greeter session to force respawn with fresh PAM
		await new Promise((resolve) => {
			const proc = this.hostSpawn('/bin/bash', ['-c',
				'GREETER=$(/usr/bin/loginctl list-sessions --no-legend | grep greeter | awk \'{print $1}\'); ' +
				'if [ -n "$GREETER" ]; then /usr/bin/sudo /usr/bin/loginctl terminate-session $GREETER; fi'
			]);
			proc.on('close', () => resolve());
			proc.on('error', () => resolve());
		});

		// Step 5: Wait for new greeter to spawn and initialize (longer wait)
		await new Promise(resolve => setTimeout(resolve, 4000));

		// Step 6: Wake screen / move mouse to ensure focus
		await new Promise((resolve) => {
			const proc = this.hostSpawn('/usr/bin/sudo', [
				'/usr/bin/env', 'DISPLAY=:0', 'XAUTHORITY=/var/lib/lightdm/.Xauthority',
				'/usr/bin/xdotool', 'mousemove', '500', '300'
			]);
			proc.on('close', () => resolve());
			proc.on('error', () => resolve());
		});

		// Step 7: Small delay
		await new Promise(resolve => setTimeout(resolve, 300));

		// Step 8: Send Enter to submit login
		await new Promise((resolve) => {
			const proc = this.hostSpawn('/usr/bin/sudo', [
				'/usr/bin/env', 'DISPLAY=:0', 'XAUTHORITY=/var/lib/lightdm/.Xauthority',
				'/usr/bin/xdotool', 'key', 'Return'
			]);
			proc.on('close', () => resolve());
			proc.on('error', () => resolve());
		});

		// Clean up trigger file after a delay (in case login failed)
		setTimeout(async () => {
			try {
				await unlink(this.triggerFile);
			} catch {
				// Ignore
			}
		}, 5000);

		console.log('🔓 Screen unlocked');
	}

	/**
	 * Execute the PAM helper script
	 * This is an alternative method using a helper binary
	 */
	async executePamHelper() {
		return new Promise((resolve, reject) => {
			const proc = spawn('/usr/local/bin/cyberdeck-pam-helper', [
				this.loginUser
			]);

			proc.on('close', (code) => {
				if (code === 0) {
					console.log('🔓 PAM helper executed successfully');
					resolve();
				} else {
					reject(new Error(`PAM helper exited with code ${code}`));
				}
			});

			proc.on('error', (error) => {
				reject(error);
			});
		});
	}
}