"use strict";
/**
 * Validation constants
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.HEX_PATTERN = exports.BLOCK_HASH_PATTERN = exports.TXID_PATTERN = exports.MEOWCOIN_XPRV_PATTERN = exports.MEOWCOIN_XPUB_PATTERN = exports.MEOWCOIN_PRIVATE_KEY_PATTERN = exports.MEOWCOIN_ADDRESS_PATTERN = exports.PORT_MAX = exports.PORT_MIN = exports.IPV6_PATTERN = exports.IPV4_PATTERN = exports.URL_PATTERN = exports.API_KEY_PATTERN = exports.NODE_NAME_PATTERN = exports.NODE_NAME_MAX_LENGTH = exports.NODE_NAME_MIN_LENGTH = exports.EMAIL_PATTERN = exports.PASSWORD_PATTERN = exports.PASSWORD_MAX_LENGTH = exports.PASSWORD_MIN_LENGTH = exports.USERNAME_PATTERN = exports.USERNAME_MAX_LENGTH = exports.USERNAME_MIN_LENGTH = void 0;
// Username validation
exports.USERNAME_MIN_LENGTH = 3;
exports.USERNAME_MAX_LENGTH = 30;
exports.USERNAME_PATTERN = /^[a-zA-Z0-9_-]+$/;
// Password validation
exports.PASSWORD_MIN_LENGTH = 12;
exports.PASSWORD_MAX_LENGTH = 128;
exports.PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]).+$/;
// Email validation
exports.EMAIL_PATTERN = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
// Node name validation
exports.NODE_NAME_MIN_LENGTH = 3;
exports.NODE_NAME_MAX_LENGTH = 50;
exports.NODE_NAME_PATTERN = /^[a-zA-Z0-9_-]+$/;
// API key validation
exports.API_KEY_PATTERN = /^[a-zA-Z0-9]{32,64}$/;
// URL validation
exports.URL_PATTERN = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;
// IP address validation
exports.IPV4_PATTERN = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
exports.IPV6_PATTERN = /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/;
// Port validation
exports.PORT_MIN = 1;
exports.PORT_MAX = 65535;
// Blockchain address validation
exports.MEOWCOIN_ADDRESS_PATTERN = /^[M3][a-km-zA-HJ-NP-Z1-9]{25,34}$/;
exports.MEOWCOIN_PRIVATE_KEY_PATTERN = /^[5-9A-HJ-NP-Za-km-z]{51,52}$/;
exports.MEOWCOIN_XPUB_PATTERN = /^xpub[a-zA-Z0-9]{107,108}$/;
exports.MEOWCOIN_XPRV_PATTERN = /^xprv[a-zA-Z0-9]{107,108}$/;
// Transaction ID validation
exports.TXID_PATTERN = /^[a-fA-F0-9]{64}$/;
// Block hash validation
exports.BLOCK_HASH_PATTERN = /^[a-fA-F0-9]{64}$/;
// Hex validation
exports.HEX_PATTERN = /^[a-fA-F0-9]+$/;
