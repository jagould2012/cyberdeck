import { readFile, writeFile, mkdir, readdir } from 'fs/promises';
import { existsSync } from 'fs';
import { dirname, join } from 'path';

/**
 * Manages configuration and registered devices
 * Watches registered/ folder for device files
 */
export class ConfigManager {
	constructor(configPath, publicKeysDir) {
		this.configPath = configPath;
		this.publicKeysDir = publicKeysDir;
		this.registeredDir = join(dirname(configPath), 'registered');
		this.config = null;
		this.registeredDevices = [];
		this.pollInterval = null;
		this.reloadTimeout = null;
	}

	async load() {
		try {
			// Ensure directories exist
			await mkdir(dirname(this.configPath), { recursive: true });
			await mkdir(this.publicKeysDir, { recursive: true });
			await mkdir(this.registeredDir, { recursive: true });

			if (existsSync(this.configPath)) {
				const data = await readFile(this.configPath, 'utf-8');
				this.config = JSON.parse(data);
				console.log(`📋 Loaded config from ${this.configPath}`);
			} else {
				// Create default config
				this.config = this.getDefaultConfig();
				await this.save();
				console.log(`📋 Created default config at ${this.configPath}`);
			}

			// Load registered devices from folder
			await this.loadRegisteredDevices();
		} catch (error) {
			console.error('Failed to load config:', error);
			this.config = this.getDefaultConfig();
		}
	}

	/**
	 * Load all device files from registered/ folder
	 */
	async loadRegisteredDevices() {
		try {
			const files = await readdir(this.registeredDir);
			const jsonFiles = files.filter(f => f.endsWith('.json'));

			this.registeredDevices = [];

			for (const file of jsonFiles) {
				try {
					const filePath = join(this.registeredDir, file);
					const data = await readFile(filePath, 'utf-8');
					const device = JSON.parse(data);
					this.registeredDevices.push(device);
				} catch (err) {
					console.error(`Failed to load device file ${file}:`, err.message);
				}
			}

			console.log(`🔑 ${this.registeredDevices.length} registered device(s) in ${this.registeredDir}`);
		} catch (error) {
			console.error('Failed to load registered devices:', error);
			this.registeredDevices = [];
		}
	}

	/**
	 * Start watching registered/ folder for changes using polling
	 */
	async startWatching() {
		// Poll every 2 seconds for changes
		this.pollInterval = setInterval(async () => {
			try {
				const files = await readdir(this.registeredDir);
				const jsonFiles = files.filter(f => f.endsWith('.json'));

				// Check if file count changed
				if (jsonFiles.length !== this.registeredDevices.length) {
					console.log(`📂 Change detected in ${this.registeredDir}`);
					await this.reloadDevices();
				}
			} catch (err) {
				// Ignore errors during polling
			}
		}, 2000);

		console.log(`👁️  Watching ${this.registeredDir} for changes (polling)`);
	}

	/**
	 * Stop watching
	 */
	stopWatching() {
		if (this.pollInterval) {
			clearInterval(this.pollInterval);
			this.pollInterval = null;
		}
		if (this.reloadTimeout) {
			clearTimeout(this.reloadTimeout);
			this.reloadTimeout = null;
		}
	}

	/**
	 * Reload devices from registered/ folder
	 */
	async reloadDevices() {
		const oldCount = this.registeredDevices.length;
		await this.loadRegisteredDevices();
		const newCount = this.registeredDevices.length;

		if (newCount > oldCount) {
			console.log(`   ✨ New device(s) added!`);
		} else if (newCount < oldCount) {
			console.log(`   🗑️  Device(s) removed`);
		}
	}

	getDefaultConfig() {
		return {
			computerName: process.env.COMPUTER_NAME || 'cyberdeck',
			loginUser: process.env.LOGIN_USER || 'pi',
			nonceRotationIntervalMs: 30000
		};
	}

	async save() {
		try {
			await writeFile(
				this.configPath,
				JSON.stringify(this.config, null, 2),
				'utf-8'
			);
		} catch (error) {
			console.error('Failed to save config:', error);
		}
	}

	get(key, defaultValue = null) {
		return this.config?.[key] ?? defaultValue;
	}

	set(key, value) {
		this.config[key] = value;
	}

	getRegisteredDevices() {
		return this.registeredDevices;
	}

	findDeviceByPublicKey(publicKey) {
		return this.registeredDevices.find(
			device => device.publicKey === publicKey
		);
	}

	isPublicKeyRegistered(publicKey) {
		return this.registeredDevices.some(
			device => device.publicKey === publicKey
		);
	}

	/**
	 * Save a captured public key to the publicKeys directory
	 * Copy to registered/ folder to enable the device
	 */
	async saveCapturedPublicKey(deviceId, publicKey, metadata = {}) {
		const keyData = {
			deviceId,
			publicKey,
			capturedAt: new Date().toISOString(),
			...metadata
		};

		const filename = `${this.publicKeysDir}/${deviceId}.json`;
		await writeFile(filename, JSON.stringify(keyData, null, 2), 'utf-8');
		console.log(`📝 Captured public key saved to ${filename}`);
		console.log(`   To register: cp ${filename} ${this.registeredDir}/`);

		return filename;
	}
}