import axios, { AxiosInstance } from 'axios';
import { 
  Block, 
  Transaction, 
  BlockchainInfo, 
  NetworkInfo, 
  MempoolInfo,
  MiningInfo,
  PeerInfo,
  AppError,
  ErrorCode
} from '@meowcoin/shared';
import { logger } from '../utils/logger';

interface RpcConfig {
  host: string;
  port: number;
  user: string;
  password: string;
  timeout?: number;
}

export class MeowCoinRPC {
  private client: AxiosInstance;
  private id = 0;

  constructor(private config: RpcConfig) {
    this.client = axios.create({
      baseURL: `http://${config.host}:${config.port}`,
      auth: {
        username: config.user,
        password: config.password,
      },
      timeout: config.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  private async call<T>(method: string, params: any[] = []): Promise<T> {
    try {
      const response = await this.client.post('/', {
        jsonrpc: '1.0',
        id: this.id++,
        method,
        params,
      });

      if (response.data.error) {
        throw new AppError(
          ErrorCode.BLOCKCHAIN_ERROR,
          `RPC Error: ${response.data.error.message}`,
          500,
          response.data.error
        );
      }

      return response.data.result;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }

      logger.error({ error, method, params }, 'RPC call failed');
      
      throw new AppError(
        ErrorCode.BLOCKCHAIN_ERROR,
        `Failed to call RPC method: ${method}`,
        500,
        error
      );
    }
  }

  // Blockchain methods
  async getBlockchainInfo(): Promise<BlockchainInfo> {
    return this.call<BlockchainInfo>('getblockchaininfo');
  }

  async getBlock(hash: string, verbose = true): Promise<Block> {
    return this.call<Block>('getblock', [hash, verbose ? 2 : 1]);
  }

  async getBlockHash(height: number): Promise<string> {
    return this.call<string>('getblockhash', [height]);
  }

  async getBlockCount(): Promise<number> {
    return this.call<number>('getblockcount');
  }

  async getRawTransaction(txid: string, verbose = true): Promise<Transaction> {
    return this.call<Transaction>('getrawtransaction', [txid, verbose]);
  }

  async getTransaction(txid: string): Promise<Transaction> {
    return this.call<Transaction>('gettransaction', [txid]);
  }

  async getMempoolInfo(): Promise<MempoolInfo> {
    return this.call<MempoolInfo>('getmempoolinfo');
  }

  async getMemoryInfo(): Promise<any> {
    return this.call<any>('getmemoryinfo');
  }

  // Network methods
  async getNetworkInfo(): Promise<NetworkInfo> {
    return this.call<NetworkInfo>('getnetworkinfo');
  }

  async getPeerInfo(): Promise<PeerInfo[]> {
    return this.call<PeerInfo[]>('getpeerinfo');
  }

  async getConnectionCount(): Promise<number> {
    return this.call<number>('getconnectioncount');
  }

  // Mining methods
  async getMiningInfo(): Promise<MiningInfo> {
    return this.call<MiningInfo>('getmininginfo');
  }

  // Control methods
  async stop(): Promise<string> {
    return this.call<string>('stop');
  }

  async uptime(): Promise<number> {
    return this.call<number>('uptime');
  }

  // Utility methods
  async validateAddress(address: string): Promise<any> {
    return this.call<any>('validateaddress', [address]);
  }

  async getBlockTemplate(): Promise<any> {
    return this.call<any>('getblocktemplate');
  }

  async submitBlock(hexData: string): Promise<any> {
    return this.call<any>('submitblock', [hexData]);
  }

  async verifyChain(checkLevel = 3, numBlocks = 6): Promise<boolean> {
    return this.call<boolean>('verifychain', [checkLevel, numBlocks]);
  }
}