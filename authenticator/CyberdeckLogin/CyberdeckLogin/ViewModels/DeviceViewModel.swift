import Foundation
import Combine

/// View model for managing device state
class DeviceViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedDevice: CyberdeckDevice?
    @Published var isAuthenticating = false
    @Published var authenticationResult: AuthResult?
    
    // MARK: - Types
    
    enum AuthResult {
        case success
        case failure(String)
    }
    
    // MARK: - Dependencies
    
    private let bleManager: BLEManager
    private let cryptoService: CryptoService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(bleManager: BLEManager, cryptoService: CryptoService) {
        self.bleManager = bleManager
        self.cryptoService = cryptoService
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func selectDevice(_ device: CyberdeckDevice) {
        selectedDevice = device
        bleManager.connect(to: device)
    }
    
    func authenticate() {
        guard selectedDevice != nil else { return }
        
        isAuthenticating = true
        authenticationResult = nil
        
        bleManager.authenticate(using: cryptoService) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthenticating = false
                self?.authenticationResult = success ? .success : .failure(error ?? "Unknown error")
            }
        }
    }
    
    func disconnect() {
        bleManager.disconnect()
        selectedDevice = nil
        authenticationResult = nil
    }
    
    func startScanning() {
        bleManager.startScanning()
    }
    
    func stopScanning() {
        bleManager.stopScanning()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Update selected device connection state
        bleManager.$connectedDevice
            .sink { [weak self] device in
                if let device = device {
                    self?.selectedDevice = device
                }
            }
            .store(in: &cancellables)
        
        // Handle authentication state changes
        bleManager.$authenticationState
            .sink { [weak self] state in
                switch state {
                case .success:
                    self?.authenticationResult = .success
                    self?.isAuthenticating = false
                case .failed(let error):
                    self?.authenticationResult = .failure(error)
                    self?.isAuthenticating = false
                case .connecting, .readingChallenge, .signing, .authenticating:
                    self?.isAuthenticating = true
                case .idle:
                    self?.isAuthenticating = false
                }
            }
            .store(in: &cancellables)
    }
}
