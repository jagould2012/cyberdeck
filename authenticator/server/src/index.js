import 'dotenv/config';
import { CyberdeckLoginServer } from './server.js';
import { ConfigManager } from './config.js';
import { NonceManager } from './nonce.js';
import { AuthService } from './auth.js';
import { BleAdvertiser } from './ble-advertiser.js';
import { BlePeripheral } from './ble-peripheral.js';
import { LockScreenMonitor } from './lock-monitor.js';
import { PamAuth } from './pam-auth.js';
import { WsBleServer } from './ws-server.js';

const CONFIG_PATH = process.env.CONFIG_PATH || '/data/config.json';
const PUBLIC_KEYS_DIR = process.env.PUBLIC_KEYS_DIR || '/data/publicKeys';
const BLE_MODE = process.env.BLE_MODE || 'native'; // 'native' or 'tcp'
const TCP_PORT = parseInt(process.env.TCP_PORT, 10) || 3100;

async function main() {
	console.log('🔐 Cyberdeck Login Server starting...');
	console.log(`📡 BLE Mode: ${BLE_MODE}`);

	try {
		// Initialize components
		const configManager = new ConfigManager(CONFIG_PATH, PUBLIC_KEYS_DIR);
		await configManager.load();

		const nonceManager = new NonceManager({
			rotationIntervalMs: configManager.get('nonceRotationIntervalMs', 30000)
		});

		const authService = new AuthService(configManager, nonceManager);
		const pamAuth = new PamAuth(configManager.get('loginUser', 'pi'));

		// Start nonce rotation
		console.log('🔄 Starting nonce rotation...');
		nonceManager.startRotation();

		if (BLE_MODE === 'tcp') {
			// WebSocket mode - receive BLE requests from Mac proxy
			console.log('📡 Starting WebSocket server (proxy mode)...');

			const wsServer = new WsBleServer({
				authService,
				pamAuth,
				configManager,
				port: TCP_PORT
			});

			await wsServer.start();

			// Handle shutdown
			process.on('SIGINT', async () => {
				console.log('\n🛑 Shutting down...');
				nonceManager.stopRotation();
				wsServer.stop();
				process.exit(0);
			});

			process.on('SIGTERM', async () => {
				console.log('\n🛑 Shutting down...');
				nonceManager.stopRotation();
				wsServer.stop();
				process.exit(0);
			});

			console.log('✅ Cyberdeck Login Server running (proxy mode)');
			console.log(`   Waiting for proxy connection on port ${TCP_PORT}...`);

		} else {
			// Native BLE mode
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
			console.log('✅ Cyberdeck Login Server running (native BLE)');
		}

	} catch (error) {
		console.error('❌ Failed to start server:', error);
		process.exit(1);
	}
}

main();