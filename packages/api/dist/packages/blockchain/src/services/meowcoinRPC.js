"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MeowCoinRPC = void 0;
const axios_1 = __importDefault(require("axios"));
const shared_1 = require("@meowcoin/shared");
const logger_1 = require("../utils/logger");
class MeowCoinRPC {
    config;
    client;
    id = 0;
    constructor(config) {
        this.config = config;
        this.client = axios_1.default.create({
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
    async call(method, params = []) {
        try {
            const response = await this.client.post('/', {
                jsonrpc: '1.0',
                id: this.id++,
                method,
                params,
            });
            if (response.data.error) {
                throw new shared_1.AppError(shared_1.ErrorCode.BLOCKCHAIN_ERROR, `RPC Error: ${response.data.error.message}`, 500, response.data.error);
            }
            return response.data.result;
        }
        catch (error) {
            if (error instanceof shared_1.AppError) {
                throw error;
            }
            logger_1.logger.error({ error, method, params }, 'RPC call failed');
            throw new shared_1.AppError(shared_1.ErrorCode.BLOCKCHAIN_ERROR, `Failed to call RPC method: ${method}`, 500, error);
        }
    }
    // Blockchain methods
    async getBlockchainInfo() {
        return this.call('getblockchaininfo');
    }
    async getBlock(hash, verbose = true) {
        return this.call('getblock', [hash, verbose ? 2 : 1]);
    }
    async getBlockHash(height) {
        return this.call('getblockhash', [height]);
    }
    async getBlockCount() {
        return this.call('getblockcount');
    }
    async getRawTransaction(txid, verbose = true) {
        return this.call('getrawtransaction', [txid, verbose]);
    }
    async getTransaction(txid) {
        return this.call('gettransaction', [txid]);
    }
    async getMempoolInfo() {
        return this.call('getmempoolinfo');
    }
    async getMemoryInfo() {
        return this.call('getmemoryinfo');
    }
    // Network methods
    async getNetworkInfo() {
        return this.call('getnetworkinfo');
    }
    async getPeerInfo() {
        return this.call('getpeerinfo');
    }
    async getConnectionCount() {
        return this.call('getconnectioncount');
    }
    // Mining methods
    async getMiningInfo() {
        return this.call('getmininginfo');
    }
    // Control methods
    async stop() {
        return this.call('stop');
    }
    async uptime() {
        return this.call('uptime');
    }
    // Utility methods
    async validateAddress(address) {
        return this.call('validateaddress', [address]);
    }
    async getBlockTemplate() {
        return this.call('getblocktemplate');
    }
    async submitBlock(hexData) {
        return this.call('submitblock', [hexData]);
    }
    async verifyChain(checkLevel = 3, numBlocks = 6) {
        return this.call('verifychain', [checkLevel, numBlocks]);
    }
}
exports.MeowCoinRPC = MeowCoinRPC;
