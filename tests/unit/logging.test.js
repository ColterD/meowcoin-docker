const fs = require('fs');
const path = require('path');
const logger = require('../../src/core/logging');

// Mock fs module
jest.mock('fs', () => ({
  existsSync: jest.fn(),
  mkdirSync: jest.fn(),
  writeFileSync: jest.fn(),
  createWriteStream: jest.fn()
}));

describe('Logging Module', () => {
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    
    // Mock filesystem functions
    fs.existsSync.mockReturnValue(false);
    fs.mkdirSync.mockImplementation(() => {});
  });
  
  test('Initializes logging system', async () => {
    await logger.initialize();
    expect(fs.mkdirSync).toHaveBeenCalled();
  });
  
  test('Logs messages with correct levels', () => {
    // Create a spy on console.log
    const consoleSpy = jest.spyOn(console, 'log').mockImplementation();
    
    logger.info('Test info message');
    logger.error('Test error message');
    logger.warn('Test warning message');
    logger.debug('Test debug message');
    
    expect(consoleSpy).toHaveBeenCalled();
    
    // Restore console.log
    consoleSpy.mockRestore();
  });
});