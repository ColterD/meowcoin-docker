"use strict";
/**
 * Blockchain constants
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.BIP44_COIN_TYPE = exports.BIP32_HARDENED_KEY_LIMIT = exports.EXT_SECRET_KEY_PREFIX = exports.EXT_PUBLIC_KEY_PREFIX = exports.SECRET_KEY_PREFIX = exports.SCRIPT_ADDRESS_PREFIX = exports.PUBKEY_ADDRESS_PREFIX = exports.DEFAULT_MIN_RELAY_TX_FEE = exports.DEFAULT_INCREMENTAL_RELAY_FEE = exports.DEFAULT_MEMPOOL_EXPIRY = exports.DEFAULT_MAX_MEMPOOL_SIZE = exports.MAX_P2SH_SIGOPS = exports.MAX_SCRIPT_OPCODES = exports.MAX_SCRIPT_ELEMENT_SIZE = exports.MAX_SCRIPT_SIZE = exports.MIN_PROTOCOL_VERSION = exports.MAX_PROTOCOL_VERSION = exports.REGTEST_RPC_PORT = exports.TESTNET_RPC_PORT = exports.MAINNET_RPC_PORT = exports.REGTEST_PORT = exports.TESTNET_PORT = exports.MAINNET_PORT = exports.DUST_RELAY_TX_FEE = exports.MIN_RELAY_TX_FEE = exports.MIN_TX_FEE = exports.HALVING_INTERVAL = exports.INITIAL_BLOCK_REWARD = exports.MAX_MONEY = exports.COIN = exports.POW_LIMIT_BITS = exports.POW_RETARGET_INTERVAL = exports.POW_TARGET_SPACING = exports.POW_TARGET_TIMESPAN = exports.POW_LIMIT = exports.MINIMUM_CHAIN_WORK = exports.COINBASE_MATURITY = exports.MAX_BLOCK_SIGOPS = exports.MAX_BLOCK_WEIGHT = exports.MAX_BLOCK_SIZE = exports.BLOCKS_PER_YEAR = exports.BLOCKS_PER_MONTH = exports.BLOCKS_PER_WEEK = exports.BLOCKS_PER_DAY = exports.BLOCK_TIME = void 0;
// Block constants
exports.BLOCK_TIME = 150; // 2.5 minutes in seconds
exports.BLOCKS_PER_DAY = Math.floor(24 * 60 * 60 / exports.BLOCK_TIME);
exports.BLOCKS_PER_WEEK = exports.BLOCKS_PER_DAY * 7;
exports.BLOCKS_PER_MONTH = exports.BLOCKS_PER_DAY * 30;
exports.BLOCKS_PER_YEAR = exports.BLOCKS_PER_DAY * 365;
// Consensus parameters
exports.MAX_BLOCK_SIZE = 1000000; // 1MB
exports.MAX_BLOCK_WEIGHT = 4000000;
exports.MAX_BLOCK_SIGOPS = 80000;
exports.COINBASE_MATURITY = 100; // blocks
exports.MINIMUM_CHAIN_WORK = "0x0000000000000000000000000000000000000000000000000000000000000000";
// Mining parameters
exports.POW_LIMIT = "00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
exports.POW_TARGET_TIMESPAN = 14 * 24 * 60 * 60; // 2 weeks in seconds
exports.POW_TARGET_SPACING = exports.BLOCK_TIME;
exports.POW_RETARGET_INTERVAL = exports.POW_TARGET_TIMESPAN / exports.POW_TARGET_SPACING;
exports.POW_LIMIT_BITS = 0x1e0fffff;
// Monetary parameters
exports.COIN = 100000000; // 1 MeowCoin = 100,000,000 satoshis
exports.MAX_MONEY = 21000000 * exports.COIN;
exports.INITIAL_BLOCK_REWARD = 50 * exports.COIN;
exports.HALVING_INTERVAL = 210000; // blocks
exports.MIN_TX_FEE = 1000; // satoshis
exports.MIN_RELAY_TX_FEE = 1000; // satoshis
exports.DUST_RELAY_TX_FEE = 3000; // satoshis
// Network parameters
exports.MAINNET_PORT = 9333;
exports.TESTNET_PORT = 19333;
exports.REGTEST_PORT = 19444;
exports.MAINNET_RPC_PORT = 9332;
exports.TESTNET_RPC_PORT = 19332;
exports.REGTEST_RPC_PORT = 19443;
exports.MAX_PROTOCOL_VERSION = 70016;
exports.MIN_PROTOCOL_VERSION = 70015;
// Script parameters
exports.MAX_SCRIPT_SIZE = 10000; // bytes
exports.MAX_SCRIPT_ELEMENT_SIZE = 520; // bytes
exports.MAX_SCRIPT_OPCODES = 201;
exports.MAX_P2SH_SIGOPS = 15;
// Mempool parameters
exports.DEFAULT_MAX_MEMPOOL_SIZE = 300; // MB
exports.DEFAULT_MEMPOOL_EXPIRY = 336; // hours
exports.DEFAULT_INCREMENTAL_RELAY_FEE = 1000; // satoshis
exports.DEFAULT_MIN_RELAY_TX_FEE = 1000; // satoshis
// Address prefixes
exports.PUBKEY_ADDRESS_PREFIX = 0x32; // Starts with M
exports.SCRIPT_ADDRESS_PREFIX = 0x05; // Starts with 3
exports.SECRET_KEY_PREFIX = 0xB0; // Starts with 6 or 7
exports.EXT_PUBLIC_KEY_PREFIX = 0x0488B21E; // Starts with xpub
exports.EXT_SECRET_KEY_PREFIX = 0x0488ADE4; // Starts with xprv
// BIP32 constants
exports.BIP32_HARDENED_KEY_LIMIT = 0x80000000;
// BIP44 constants
exports.BIP44_COIN_TYPE = 0x8000002A; // 42'
