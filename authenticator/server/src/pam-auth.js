import { spawn } from 'child_process';
import { writeFile, unlink } from 'fs/promises';

/**
 * Handles PAM-based login without password
 * Requires the cyberdeck-login PAM module to be installed
 */
export class PamAuth {
	constructor(loginUser) {
		this.loginUser = loginUser;
		this.triggerFile = '/tmp/cyberdeck-login-trigger';
	}

	/**
	 * Trigger login for the configured user
	 * This creates a trigger file that the PAM module watches for
	 */
	async triggerLogin() {
		console.log(`🔓 Triggering PAM login for user: ${this.loginUser}`);

		try {
			// Method 1: Write trigger file for PAM module
			await this.writeTriggerFile();

			// Method 2: Try to unlock via loginctl (systemd)
			await this.unlockViaLoginctl();

			// Method 3: Try to unlock via D-Bus
			await this.unlockViaDbus();

			// Clean up trigger file after a delay
			setTimeout(async () => {
				try {
					await unlink(this.triggerFile);
				} catch {
					// Ignore
				}
			}, 5000);

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
			mode: 0o600
		});
		console.log('📝 Trigger file written');
	}

	/**
	 * Try to unlock session via loginctl
	 */
	async unlockViaLoginctl() {
		return new Promise((resolve) => {
			const proc = spawn('loginctl', ['unlock-sessions']);

			proc.on('close', (code) => {
				if (code === 0) {
					console.log('🔓 Sessions unlocked via loginctl');
				}
				resolve();
			});

			proc.on('error', () => {
				resolve();
			});
		});
	}

	/**
	 * Try to unlock via D-Bus screensaver interface
	 */
	async unlockViaDbus() {
		return new Promise((resolve) => {
			// Try GNOME screensaver
			const proc = spawn('dbus-send', [
				'--session',
				'--type=method_call',
				'--dest=org.gnome.ScreenSaver',
				'/org/gnome/ScreenSaver',
				'org.gnome.ScreenSaver.SetActive',
				'boolean:false'
			]);

			proc.on('close', () => {
				resolve();
			});

			proc.on('error', () => {
				resolve();
			});
		});
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