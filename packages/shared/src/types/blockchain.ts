/**
 * Block information
 */
export interface Block {
  hash: string;
  height: number;
  confirmations: number;
  size: number;
  weight: number;
  version: number;
  versionHex: string;
  merkleroot: string;
  time: number;
  mediantime: number;
  nonce: number;
  bits: string;
  difficulty: number;
  chainwork: string;
  nTx: number;
  previousblockhash?: string;
  nextblockhash?: string;
  strippedsize: number;
  tx: string[]; // Array of transaction IDs
}

/**
 * Transaction information
 */
export interface Transaction {
  txid: string;
  hash: string;
  version: number;
  size: number;
  vsize: number;
  weight: number;
  locktime: number;
  vin: TransactionInput[];
  vout: TransactionOutput[];
  hex: string;
  blockhash?: string;
  confirmations?: number;
  time?: number;
  blocktime?: number;
  fee?: number;
}

/**
 * Transaction input
 */
export interface TransactionInput {
  txid?: string;
  vout?: number;
  scriptSig?: {
    asm: string;
    hex: string;
  };
  sequence: number;
  coinbase?: string;
  txinwitness?: string[];
  value?: number;
  address?: string;
}

/**
 * Transaction output
 */
export interface TransactionOutput {
  value: number;
  n: number;
  scriptPubKey: {
    asm: string;
    hex: string;
    reqSigs?: number;
    type: string;
    addresses?: string[];
    address?: string;
  };
}

/**
 * Blockchain info
 */
export interface BlockchainInfo<Softfork = unknown> {
  chain: 'main' | 'test' | 'regtest';
  blocks: number;
  headers: number;
  bestblockhash: string;
  difficulty: number;
  mediantime: number;
  verificationprogress: number;
  initialblockdownload: boolean;
  chainwork: string;
  size_on_disk: number;
  pruned: boolean;
  pruneheight?: number;
  automatic_pruning?: boolean;
  prune_target_size?: number;
  softforks: Record<string, Softfork>;
  warnings?: string;
}

/**
 * Softfork information
 */
export interface SoftforkInfo {
  type: string;
  active: boolean;
  height?: number;
  bip9?: {
    status: string;
    start_time: number;
    timeout: number;
    since: number;
  };
}

/**
 * Network info
 */
export interface NetworkInfo {
  version: number;
  subversion: string;
  protocolversion: number;
  localservices: string;
  localrelay: boolean;
  timeoffset: number;
  connections: number;
  connections_in: number;
  connections_out: number;
  networkactive: boolean;
  networks: NetworkInterface[];
  relayfee: number;
  incrementalfee: number;
  localaddresses: LocalAddress[];
  warnings?: string;
}

/**
 * Network interface
 */
export interface NetworkInterface {
  name: string;
  limited: boolean;
  reachable: boolean;
  proxy: string;
  proxy_randomize_credentials: boolean;
}

/**
 * Local address
 */
export interface LocalAddress {
  address: string;
  port: number;
  score: number;
}

/**
 * Peer info
 */
export interface PeerInfo {
  id: number;
  addr: string;
  addrbind: string;
  addrlocal: string;
  services: string;
  relaytxes: boolean;
  lastsend: number;
  lastrecv: number;
  bytessent: number;
  bytesrecv: number;
  conntime: number;
  timeoffset: number;
  pingtime: number;
  minping: number;
  version: number;
  subver: string;
  inbound: boolean;
  addnode: boolean;
  startingheight: number;
  banscore: number;
  synced_headers: number;
  synced_blocks: number;
  inflight: number[];
  whitelisted: boolean;
  permissions: string[];
  minfeefilter: number;
}

/**
 * Mempool info
 */
export interface MempoolInfo {
  loaded: boolean;
  size: number;
  bytes: number;
  usage: number;
  maxmempool: number;
  mempoolminfee: number;
  minrelaytxfee: number;
}

/**
 * Mining info
 */
export interface MiningInfo {
  blocks: number;
  currentblockweight?: number;
  currentblocktx?: number;
  difficulty: number;
  networkhashps: number;
  pooledtx: number;
  chain: string;
  warnings?: string;
}

/**
 * Wallet info
 */
export interface WalletInfo {
  walletname: string;
  walletversion: number;
  balance: number;
  unconfirmed_balance: number;
  immature_balance: number;
  txcount: number;
  keypoololdest: number;
  keypoolsize: number;
  keypoolsize_hd_internal: number;
  paytxfee: number;
  hdseedid?: string;
  private_keys_enabled: boolean;
  avoid_reuse: boolean;
  scanning: boolean;
  descriptors: boolean;
}

/**
 * Memory info (from getmemoryinfo)
 */
export interface MemoryInfo {
  locked: {
    used: number;
    free: number;
    total: number;
    locked: number;
    chunks_used: number;
    chunks_free: number;
  };
}

/**
 * Validate address response (from validateaddress)
 */
export interface ValidateAddressResponse {
  isvalid: boolean;
  address?: string;
  scriptPubKey?: string;
  isscript?: boolean;
  iswitness?: boolean;
  witness_version?: number;
  witness_program?: string;
  pubkey?: string;
  ismine?: boolean;
  iswatchonly?: boolean;
  hdkeypath?: string;
  hdmasterfingerprint?: string;
  labels?: string[];
  // Add more fields as needed
}

/**
 * Block template (from getblocktemplate)
 */
export interface BlockTemplate<VB = number, AUX = string> {
  version: number;
  rules: string[];
  vbavailable: Record<string, VB>;
  vbrequired: number;
  previousblockhash: string;
  transactions: Array<{
    data: string;
    hash: string;
    depends: number[];
    fee: number;
    sigops: number;
    weight: number;
  }>;
  coinbaseaux: Record<string, AUX>;
  coinbasevalue: number;
  longpollid: string;
  target: string;
  mintime: number;
  mutable: string[];
  noncerange: string;
  sigoplimit: number;
  sizelimit: number;
  weightlimit: number;
  curtime: number;
  bits: string;
  height: number;
  default_witness_commitment?: string;
  // Add more fields as needed
}

/**
 * Submit block response (from submitblock)
 */
export type SubmitBlockResponse = null | string; // null if accepted, string error otherwise