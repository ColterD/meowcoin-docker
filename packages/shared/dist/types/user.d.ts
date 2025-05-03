/**
 * User roles
 */
export declare enum UserRole {
    ADMIN = "admin",
    OPERATOR = "operator",
    VIEWER = "viewer",
    API = "api"
}
/**
 * User status
 */
export declare enum UserStatus {
    ACTIVE = "active",
    INACTIVE = "inactive",
    PENDING = "pending",
    LOCKED = "locked"
}
/**
 * MFA method
 */
export declare enum MfaMethod {
    TOTP = "totp",
    SMS = "sms",
    EMAIL = "email",
    RECOVERY_CODES = "recovery_codes"
}
/**
 * User profile
 */
export interface UserProfile {
    id: string;
    username: string;
    email: string;
    firstName?: string;
    lastName?: string;
    role: UserRole;
    status: UserStatus;
    createdAt: string;
    updatedAt: string;
    lastLogin?: string;
    preferences: UserPreferences;
    mfaEnabled: boolean;
    mfaMethods: MfaMethod[];
}
/**
 * User preferences
 */
export interface UserPreferences {
    theme: 'light' | 'dark' | 'system';
    language: string;
    timezone: string;
    dateFormat: string;
    timeFormat: string;
    notifications: {
        email: boolean;
        sms: boolean;
        browser: boolean;
        slack?: boolean;
        telegram?: boolean;
        discord?: boolean;
    };
    dashboardLayout?: any;
}
/**
 * User credentials
 */
export interface UserCredentials {
    username: string;
    password: string;
    mfaCode?: string;
    mfaMethod?: MfaMethod;
}
/**
 * Authentication response
 */
export interface AuthResponse {
    token: string;
    refreshToken: string;
    expiresIn: number;
    user: UserProfile;
    mfaRequired?: boolean;
    mfaMethods?: MfaMethod[];
}
/**
 * Token payload
 */
export interface TokenPayload {
    sub: string;
    username: string;
    email: string;
    role: UserRole;
    iat: number;
    exp: number;
}
/**
 * Permission
 */
export interface Permission {
    id: string;
    name: string;
    description: string;
    resource: string;
    action: 'create' | 'read' | 'update' | 'delete' | 'manage';
}
/**
 * API key
 */
export interface ApiKey {
    id: string;
    name: string;
    key: string;
    prefix: string;
    userId: string;
    permissions: string[];
    expiresAt?: string;
    lastUsed?: string;
    createdAt: string;
    createdByIp: string;
}
/**
 * Audit log entry
 */
export interface AuditLogEntry {
    id: string;
    userId: string;
    username: string;
    action: string;
    resource: string;
    resourceId?: string;
    timestamp: string;
    ip: string;
    userAgent: string;
    details?: any;
}
