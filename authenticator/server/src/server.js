/**
 * Main server class that orchestrates all components
 */
export class CyberdeckLoginServer {
	constructor({
		configManager,
		nonceManager,
		authService,
		bleAdvertiser,
		blePeripheral,
		lockMonitor,
		pamAuth
	}) {
		this.configManager = configManager;
		this.nonceManager = nonceManager;
		this.authService = authService;
		this.bleAdvertiser = bleAdvertiser;
		this.blePeripheral = blePeripheral;
		this.lockMonitor = lockMonitor;
		this.pamAuth = pamAuth;

		this.isAdvertising = false;
		this.registrationMode = false;
	}

	async start() {
		console.log('📡 Initializing BLE peripheral...');
		await this.blePeripheral.initialize();

		console.log('👁️  Starting lock screen monitor...');
		this.lockMonitor.on('locked', () => this.onScreenLocked());
		this.lockMonitor.on('unlocked', () => this.onScreenUnlocked());
		this.lockMonitor.on('idle', () => this.onIdle());
		this.lockMonitor.on('active', () => this.onActive());
		await this.lockMonitor.start();

		// Start nonce rotation
		console.log('🔄 Starting nonce rotation...');
		this.nonceManager.startRotation();

		// Check initial state
		const isLocked = await this.lockMonitor.isLocked();
		if (isLocked) {
			console.log('🔒 Screen is locked, starting advertisement...');
			await this.startAdvertising();
		} else {
			console.log('🔓 Screen is unlocked, waiting...');
		}
	}

	async stop() {
		this.nonceManager.stopRotation();
		await this.stopAdvertising();
		this.lockMonitor.stop();
		await this.blePeripheral.shutdown();
	}

	async onScreenLocked() {
		console.log('🔒 Screen locked - starting BLE advertisement');
		await this.startAdvertising();
	}

	async onScreenUnlocked() {
		console.log('🔓 Screen unlocked - stopping BLE advertisement');
		await this.stopAdvertising();
	}

	async onIdle() {
		console.log('💤 System idle - starting BLE advertisement');
		await this.startAdvertising();
	}

	async onActive() {
		console.log('⚡ System active');
		// Only stop if screen is also unlocked
		const isLocked = await this.lockMonitor.isLocked();
		if (!isLocked) {
			await this.stopAdvertising();
		}
	}

	async startAdvertising() {
		if (this.isAdvertising) return;

		this.isAdvertising = true;
		await this.bleAdvertiser.startAdvertising();
		await this.blePeripheral.startServices();
	}

	async stopAdvertising() {
		if (!this.isAdvertising) return;

		this.isAdvertising = false;
		await this.bleAdvertiser.stopAdvertising();
		await this.blePeripheral.stopServices();
	}

	async enterRegistrationMode(durationMs = 60000) {
		console.log(`📝 Entering registration mode for ${durationMs / 1000}s...`);
		this.registrationMode = true;
		this.blePeripheral.setRegistrationMode(true);

		setTimeout(() => {
			this.exitRegistrationMode();
		}, durationMs);
	}

	exitRegistrationMode() {
		console.log('📝 Exiting registration mode');
		this.registrationMode = false;
		this.blePeripheral.setRegistrationMode(false);
	}
}