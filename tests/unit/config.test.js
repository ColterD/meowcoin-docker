const fs = require('fs');
const path = require('path');
const config = require('../../src/core/config');

// Mock fs module
jest.mock('fs', () => ({
  existsSync: jest.fn(),
  readFileSync: jest.fn(),
  writeFileSync: jest.fn(),
  mkdirSync: jest.fn()
}));

describe('Config Module', () => {
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    
    // Mock filesystem functions
    fs.existsSync.mockReturnValue(false);
    fs.readFileSync.mockImplementation((file) => {
      if (file.includes('config.yaml')) {
        return 'rpcUser: testuser\nrpcBind: 127.0.0.1';
      }
      return '';
    });
  });
  
  test('Initializes with default values', async () => {
    await config.initialize();
    
    expect(config.get('rpcUser')).toBe('meowcoin');
    expect(config.get('rpcBind')).toBe('127.0.0.1');
    expect(config.get('enableSsl')).toBe(false);
  });
  
  test('Loads values from configuration file', async () => {
    fs.existsSync.mockReturnValue(true);
    
    await config.initialize();
    
    expect(config.get('rpcUser')).toBe('testuser');
  });
  
  test('Gets and sets configuration values', async () => {
    await config.initialize();
    
    config.set('testKey', 'testValue');
    expect(config.get('testKey')).toBe('testValue');
    
    expect(config.get('nonExistentKey', 'defaultValue')).toBe('defaultValue');
  });
});