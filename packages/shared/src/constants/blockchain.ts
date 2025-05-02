/**
 * Blockchain constants
 */

// Block constants
export const BLOCK_TIME = 150; // 2.5 minutes in seconds
export const BLOCKS_PER_DAY = Math.floor(24 * 60 * 60 / BLOCK_TIME);
export const BLOCKS_PER_WEEK = BLOCKS_PER_DAY * 7;
export const BLOCKS_PER_MONTH = BLOCKS_PER_DAY * 30;
export const BLOCKS_PER_YEAR = BLOCKS_PER_DAY * 365;

// Consensus parameters
export const MAX_BLOCK_SIZE = 1000000; // 1MB
export const MAX_BLOCK_WEIGHT = 4000000;
export const MAX_BLOCK_SIGOPS = 80000;
export const COINBASE_MATURITY = 100; // blocks
export const MINIMUM_CHAIN_WORK = "0x0000000000000000000000000000000000000000000000000000000000000000";

// Mining parameters
export const POW_LIMIT = "00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
export const POW_TARGET_TIMESPAN = 14 * 24 * 60 * 60; // 2 weeks in seconds
export const POW_TARGET_SPACING = BLOCK_TIME;
export const POW_RETARGET_INTERVAL = POW_TARGET_TIMESPAN / POW_TARGET_SPACING;
export const POW_LIMIT_BITS = 0x1e0fffff;

// Monetary parameters
export const COIN = 100000000; // 1 MeowCoin = 100,000,000 satoshis
export const MAX_MONEY = 21000000 * COIN;
export const INITIAL_BLOCK_REWARD = 50 * COIN;
export const HALVING_INTERVAL = 210000; // blocks
export const MIN_TX_FEE = 1000; // satoshis
export const MIN_RELAY_TX_FEE = 1000; // satoshis
export const DUST_RELAY_TX_FEE = 3000; // satoshis

// Network parameters
export const MAINNET_PORT = 9333;
export const TESTNET_PORT = 19333;
export const REGTEST_PORT = 19444;
export const MAINNET_RPC_PORT = 9332;
export const TESTNET_RPC_PORT = 19332;
export const REGTEST_RPC_PORT = 19443;
export const MAX_PROTOCOL_VERSION = 70016;
export const MIN_PROTOCOL_VERSION = 70015;

// Script parameters
export const MAX_SCRIPT_SIZE = 10000; // bytes
export const MAX_SCRIPT_ELEMENT_SIZE = 520; // bytes
export const MAX_SCRIPT_OPCODES = 201;
export const MAX_P2SH_SIGOPS = 15;

// Mempool parameters
export const DEFAULT_MAX_MEMPOOL_SIZE = 300; // MB
export const DEFAULT_MEMPOOL_EXPIRY = 336; // hours
export const DEFAULT_INCREMENTAL_RELAY_FEE = 1000; // satoshis
export const DEFAULT_MIN_RELAY_TX_FEE = 1000; // satoshis

// Address prefixes
export const PUBKEY_ADDRESS_PREFIX = 0x32; // Starts with M
export const SCRIPT_ADDRESS_PREFIX = 0x05; // Starts with 3
export const SECRET_KEY_PREFIX = 0xB0; // Starts with 6 or 7
export const EXT_PUBLIC_KEY_PREFIX = 0x0488B21E; // Starts with xpub
export const EXT_SECRET_KEY_PREFIX = 0x0488ADE4; // Starts with xprv

// BIP32 constants
export const BIP32_HARDENED_KEY_LIMIT = 0x80000000;

// BIP44 constants
export const BIP44_COIN_TYPE = 0x8000002A; // 42'