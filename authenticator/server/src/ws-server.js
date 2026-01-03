import { WebSocketServer } from 'ws';

/**
 * WebSocket server that receives BLE requests from the Mac proxy
 * Maintains a persistent connection for cleaner communication
 */
export class WsBleServer {
	constructor({ authService, pamAuth, configManager, port = 3100 }) {
		this.authService = authService;
		this.pamAuth = pamAuth;
		this.configManager = configManager;
		this.port = port;
		this.wss = null;
		this.connectedProxy = null;
	}

	start() {
		return new Promise((resolve, reject) => {
			this.wss = new WebSocketServer({ port: this.port });

			this.wss.on('listening', () => {
				console.log(`📡 WebSocket server listening on port ${this.port}`);
				resolve();
			});

			this.wss.on('error', (err) => {
				reject(err);
			});

			this.wss.on('connection', (ws, req) => {
				const clientIp = req.socket.remoteAddress;
				console.log(`✅ Proxy connected from: ${clientIp}`);
				console.log('🔗 Ready for BLE requests');

				this.connectedProxy = ws;

				ws.on('message', async (data) => {
					await this.handleMessage(ws, data.toString());
				});

				ws.on('close', () => {
					console.log('📡 Proxy disconnected');
					this.connectedProxy = null;
				});

				ws.on('error', (err) => {
					console.error('WebSocket error:', err.message);
				});

				// Send welcome message
				ws.send(JSON.stringify({ type: 'connected', message: 'Server ready' }));
			});
		});
	}

	async handleMessage(ws, message) {
		try {
			const { id, action, data } = JSON.parse(message);
			let response;

			switch (action) {
				case 'getChallenge':
					response = this.handleGetChallenge();
					break;

				case 'authenticate':
					response = await this.handleAuthenticate(data);
					break;

				case 'register':
					response = await this.handleRegister(data);
					break;

				case 'ping':
					response = { success: true, pong: true };
					break;

				default:
					response = { success: false, error: 'Unknown action' };
			}

			// Include request id for correlation
			ws.send(JSON.stringify({ id, ...response }));
		} catch (error) {
			console.error('Message error:', error);
			ws.send(JSON.stringify({ success: false, error: error.message }));
		}
	}

	handleGetChallenge() {
		const challenge = this.authService.generateChallenge();
		console.log('📤 Challenge requested');
		return { success: true, challenge };
	}

	async handleAuthenticate(data) {
		const { signedNonce, publicKey } = data;
		console.log('🔐 Auth attempt received');

		const result = this.authService.verifyAuthentication(signedNonce, publicKey);

		if (result.valid) {
			console.log(`✅ Auth successful for: ${result.deviceName}`);
			try {
				await this.pamAuth.triggerLogin();
				return { success: true, deviceName: result.deviceName };
			} catch (error) {
				console.error('PAM error:', error);
				return { success: false, error: 'PAM login failed' };
			}
		} else {
			console.log(`❌ Auth failed: ${result.error}`);
			return { success: false, error: result.error };
		}
	}

	async handleRegister(data) {
		const { deviceId, publicKey, deviceName } = data;
		console.log(`📝 Registration request from: ${deviceName || deviceId}`);

		try {
			await this.configManager.saveCapturedPublicKey(deviceId, publicKey, {
				deviceName: deviceName || 'Unknown Device'
			});
			return { success: true };
		} catch (error) {
			return { success: false, error: error.message };
		}
	}

	stop() {
		if (this.wss) {
			this.wss.close();
			this.wss = null;
		}
	}
}