import { Block, Transaction, BlockchainInfo, NetworkInfo, MempoolInfo, MiningInfo, PeerInfo, MemoryInfo, ValidateAddressResponse, BlockTemplate, SubmitBlockResponse } from '../types/blockchain';
interface RpcConfig {
    host: string;
    port: number;
    user: string;
    password: string;
    timeout?: number;
}
export declare class MeowCoinRPC {
    private config;
    private client;
    private id;
    constructor(config: RpcConfig);
    private call;
    getBlockchainInfo(): Promise<BlockchainInfo>;
    getBlock(hash: string, verbose?: boolean): Promise<Block>;
    getBlockHash(height: number): Promise<string>;
    getBlockCount(): Promise<number>;
    getRawTransaction(txid: string, verbose?: boolean): Promise<Transaction>;
    getTransaction(txid: string): Promise<Transaction>;
    getMempoolInfo(): Promise<MempoolInfo>;
    getMemoryInfo(): Promise<MemoryInfo>;
    getNetworkInfo(): Promise<NetworkInfo>;
    getPeerInfo(): Promise<PeerInfo[]>;
    getConnectionCount(): Promise<number>;
    getMiningInfo(): Promise<MiningInfo>;
    stop(): Promise<string>;
    uptime(): Promise<number>;
    validateAddress(address: string): Promise<ValidateAddressResponse>;
    getBlockTemplate(): Promise<BlockTemplate>;
    submitBlock(hexData: string): Promise<SubmitBlockResponse>;
    verifyChain(checkLevel?: number, numBlocks?: number): Promise<boolean>;
}
export {};
