/* eslint-env jest */

import * as nodeManager from './nodeManager';
import { MeowCoinRPC } from './meowcoinRPC';

jest.mock('./meowcoinRPC');

const mockRpc = {
  getBlockchainInfo: jest.fn(),
  getNetworkInfo: jest.fn(),
  getMemoryInfo: jest.fn(),
  getMiningInfo: jest.fn(),
  stop: jest.fn(),
};

beforeEach(() => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (MeowCoinRPC as any).mockImplementation(() => mockRpc);
  jest.clearAllMocks();
});

describe('nodeManager', () => {
  it('should initialize without error if node is running', async () => {
    mockRpc.getBlockchainInfo.mockResolvedValueOnce({});
    await expect(nodeManager.initializeNodeManager()).resolves.not.toThrow();
  });

  it('should start node if not running', async () => {
    mockRpc.getBlockchainInfo.mockRejectedValueOnce(new Error('not running'));
    mockRpc.getBlockchainInfo.mockResolvedValueOnce({});
    await expect(nodeManager.initializeNodeManager()).resolves.not.toThrow();
  });

  it('should throw if node fails to start', async () => {
    mockRpc.getBlockchainInfo.mockRejectedValue(new Error('fail'));
    await expect(nodeManager.initializeNodeManager()).rejects.toThrow();
  });

  // TODO: Add more unit tests for node lifecycle, monitoring, backup
  // TODO: Add integration tests with a real node
  // TODO: Add tests for multi-node support
}); 