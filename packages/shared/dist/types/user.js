"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MfaMethod = exports.UserStatus = exports.UserRole = void 0;
/**
 * User roles
 */
var UserRole;
(function (UserRole) {
    UserRole["ADMIN"] = "admin";
    UserRole["OPERATOR"] = "operator";
    UserRole["VIEWER"] = "viewer";
    UserRole["API"] = "api";
})(UserRole || (exports.UserRole = UserRole = {}));
/**
 * User status
 */
var UserStatus;
(function (UserStatus) {
    UserStatus["ACTIVE"] = "active";
    UserStatus["INACTIVE"] = "inactive";
    UserStatus["PENDING"] = "pending";
    UserStatus["LOCKED"] = "locked";
})(UserStatus || (exports.UserStatus = UserStatus = {}));
/**
 * MFA method
 */
var MfaMethod;
(function (MfaMethod) {
    MfaMethod["TOTP"] = "totp";
    MfaMethod["SMS"] = "sms";
    MfaMethod["EMAIL"] = "email";
    MfaMethod["RECOVERY_CODES"] = "recovery_codes";
})(MfaMethod || (exports.MfaMethod = MfaMethod = {}));
