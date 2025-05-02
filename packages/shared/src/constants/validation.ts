/**
 * Validation constants
 */

// Username validation
export const USERNAME_MIN_LENGTH = 3;
export const USERNAME_MAX_LENGTH = 30;
export const USERNAME_PATTERN = /^[a-zA-Z0-9_-]+$/;

// Password validation
export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_MAX_LENGTH = 128;
export const PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]).+$/;

// Email validation
export const EMAIL_PATTERN = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

// Node name validation
export const NODE_NAME_MIN_LENGTH = 3;
export const NODE_NAME_MAX_LENGTH = 50;
export const NODE_NAME_PATTERN = /^[a-zA-Z0-9_-]+$/;

// API key validation
export const API_KEY_PATTERN = /^[a-zA-Z0-9]{32,64}$/;

// URL validation
export const URL_PATTERN = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;

// IP address validation
export const IPV4_PATTERN = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
export const IPV6_PATTERN = /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/;

// Port validation
export const PORT_MIN = 1;
export const PORT_MAX = 65535;

// Blockchain address validation
export const MEOWCOIN_ADDRESS_PATTERN = /^[M3][a-km-zA-HJ-NP-Z1-9]{25,34}$/;
export const MEOWCOIN_PRIVATE_KEY_PATTERN = /^[5-9A-HJ-NP-Za-km-z]{51,52}$/;
export const MEOWCOIN_XPUB_PATTERN = /^xpub[a-zA-Z0-9]{107,108}$/;
export const MEOWCOIN_XPRV_PATTERN = /^xprv[a-zA-Z0-9]{107,108}$/;

// Transaction ID validation
export const TXID_PATTERN = /^[a-fA-F0-9]{64}$/;

// Block hash validation
export const BLOCK_HASH_PATTERN = /^[a-fA-F0-9]{64}$/;

// Hex validation
export const HEX_PATTERN = /^[a-fA-F0-9]+$/;