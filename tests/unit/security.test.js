const fs = require('fs');
const { execSync } = require('child_process');
const security = require('../../src/core/security');

// Mock fs and execSync
jest.mock('fs', () => ({
  existsSync: jest.fn(),
  mkdirSync: jest.fn(),
  writeFileSync: jest.fn(),
  readFileSync: jest.fn(),
  chmodSync: jest.fn(),
  statSync: jest.fn()
}));

jest.mock('child_process', () => ({
  execSync: jest.fn()
}));

describe('Security Module', () => {
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    
    // Mock filesystem functions
    fs.existsSync.mockReturnValue(false);
    fs.readFileSync.mockReturnValue('test data');
    execSync.mockReturnValue('test output');
  });
  
  test('Initializes security system', async () => {
    await security.initialize();
    expect(fs.mkdirSync).toHaveBeenCalled();
  });
  
  test('Generates SSL certificates when not present', async () => {
    fs.existsSync.mockReturnValue(false);
    
    await security.setupSsl();
    
    expect(execSync).toHaveBeenCalled();
    expect(fs.writeFileSync).toHaveBeenCalled();
  });
  
  test('Generates secure password with required length', () => {
    const password = security.generateSecurePassword(32);
    expect(password.length).toBe(32);
  });
});