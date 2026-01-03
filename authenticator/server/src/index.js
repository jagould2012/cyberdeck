import { CyberdeckLoginServer } from './server.js';
import { ConfigManager } from './config.js';
import { NonceManager } from './nonce.js';
import { AuthService } from './auth.js';
import { BleAdvertiser } from './ble-advertiser.js';
import { BlePeripheral } from './ble-peripheral.js';
import { LockScreenMonitor } from './lock-monitor.js';
import { PamAuth } from './pam-auth.js';

const CONFIG_PATH = process.env.CONFIG_PATH || '/data/config.json';
const PUBLIC_KEYS_DIR = process.env.PUBLIC_KEYS_DIR || '/data/publicKeys';

async function main() {
	console.log('🔐 Cyberdeck Login Server starting...');

	try {
		// Initialize components
		const configManager = new ConfigManager(CONFIG_PATH, PUBLIC_KEYS_DIR);
		await configManager.load();

		const nonceManager = new NonceManager({
			rotationIntervalMs: configManager.get('nonceRotationIntervalMs', 30000)
		});

		const authService = new AuthService(configManager, nonceManager);
		const pamAuth = new PamAuth(configManager.get('loginUser', 'pi'));
		const lockMonitor = new LockScreenMonitor();

		const bleAdvertiser = new BleAdvertiser({
			computerName: configManager.get('computerName', 'cyberdeck'),
			nonceManager
		});

		const blePeripheral = new BlePeripheral({
			authService,
			pamAuth,
			configManager,
			onSuccessfulAuth: () => {
				console.log('✅ Authentication successful, triggering login...');
			}
		});

		// Create and start server
		const server = new CyberdeckLoginServer({
			configManager,
			nonceManager,
			authService,
			bleAdvertiser,
			blePeripheral,
			lockMonitor,
			pamAuth
		});

		// Handle shutdown gracefully
		process.on('SIGINT', async () => {
			console.log('\n🛑 Shutting down...');
			await server.stop();
			process.exit(0);
		});

		process.on('SIGTERM', async () => {
			console.log('\n🛑 Shutting down...');
			await server.stop();
			process.exit(0);
		});

		await server.start();
		console.log('✅ Cyberdeck Login Server running');

	} catch (error) {
		console.error('❌ Failed to start server:', error);
		process.exit(1);
	}
}

main();