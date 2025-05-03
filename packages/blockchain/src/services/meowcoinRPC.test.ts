/* eslint-env jest */
import { MeowCoinRPC } from './meowcoinRPC';
import { AppError } from '@meowcoin/shared';
import axios from 'axios';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

const mockLogger = {
  error: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
};

describe('MeowCoinRPC', () => {
  const config = {
    host: 'localhost',
    port: 1234,
    user: 'user',
    password: 'pass',
  };
  let rpc: MeowCoinRPC;

  beforeEach(() => {
    rpc = new MeowCoinRPC(config, mockLogger);
    mockedAxios.create.mockReturnThis();
    mockedAxios.post.mockReset();
    jest.clearAllMocks();
  });

  it('should instantiate without error', () => {
    expect(rpc).toBeInstanceOf(MeowCoinRPC);
  });

  it('should throw AppError on RPC error', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { error: { message: 'fail' } } });
    await expect(rpc.getBlockchainInfo()).rejects.toBeInstanceOf(AppError);
  });

  it('should call axios.post with correct method', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { chain: 'main', blocks: 1, headers: 1, bestblockhash: '', difficulty: 1, mediantime: 1, verificationprogress: 1, initialblockdownload: false, chainwork: '', size_on_disk: 1, pruned: false, softforks: {}, } } });
    await rpc.getBlockchainInfo();
    expect(mockedAxios.post).toHaveBeenCalledWith('/', expect.objectContaining({ method: 'getblockchaininfo' }));
  });

  it('should get block by hash', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { hash: 'abc', height: 1 } } });
    const block = await rpc.getBlock('abc');
    expect(block.hash).toBe('abc');
  });

  it('should get block hash by height', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: 'blockhash' } });
    const hash = await rpc.getBlockHash(1);
    expect(hash).toBe('blockhash');
  });

  it('should get raw transaction', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { txid: 'txid' } } });
    const tx = await rpc.getRawTransaction('txid');
    expect(tx.txid).toBe('txid');
  });

  it('should get transaction', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { txid: 'txid' } } });
    const tx = await rpc.getTransaction('txid');
    expect(tx.txid).toBe('txid');
  });

  it('should get mempool info', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { loaded: true } } });
    const info = await rpc.getMempoolInfo();
    expect(info.loaded).toBe(true);
  });

  it('should get memory info', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { locked: { used: 1, free: 1, total: 2, locked: 0, chunks_used: 1, chunks_free: 1 } } } });
    const info = await rpc.getMemoryInfo();
    expect(info.locked.used).toBe(1);
  });

  it('should get network info', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { version: 1, subversion: '', protocolversion: 1, localservices: '', localrelay: true, timeoffset: 0, connections: 1, connections_in: 0, connections_out: 0, networkactive: true, networks: [], relayfee: 0, incrementalfee: 0, localaddresses: [] } } });
    const info = await rpc.getNetworkInfo();
    expect(info.version).toBe(1);
  });

  it('should get peer info', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: [{ id: 1 }] } });
    const peers = await rpc.getPeerInfo();
    expect(peers[0].id).toBe(1);
  });

  it('should get mining info', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { blocks: 1, difficulty: 1, networkhashps: 1, pooledtx: 1, chain: 'main' } } });
    const info = await rpc.getMiningInfo();
    expect(info.blocks).toBe(1);
  });

  it('should stop node', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: 'stopped' } });
    const result = await rpc.stop();
    expect(result).toBe('stopped');
  });

  it('should get uptime', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: 42 } });
    const uptime = await rpc.uptime();
    expect(uptime).toBe(42);
  });

  it('should validate address', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { isvalid: true } } });
    const res = await rpc.validateAddress('address');
    expect(res.isvalid).toBe(true);
  });

  it('should get block template', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: { version: 1, rules: [], vbavailable: {}, vbrequired: 0, previousblockhash: '', transactions: [], coinbaseaux: {}, coinbasevalue: 0, longpollid: '', target: '', mintime: 0, mutable: [], noncerange: '', sigoplimit: 0, sizelimit: 0, weightlimit: 0, curtime: 0, bits: '', height: 0 } } });
    const tpl = await rpc.getBlockTemplate();
    expect(tpl.version).toBe(1);
  });

  it('should submit block', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: null } });
    const res = await rpc.submitBlock('hex');
    expect(res).toBeNull();
  });

  it('should verify chain', async () => {
    mockedAxios.post.mockResolvedValueOnce({ data: { result: true } });
    const res = await rpc.verifyChain();
    expect(res).toBe(true);
  });

  // TODO: Add integration tests with a real node (requires testnet or local node)
}); 