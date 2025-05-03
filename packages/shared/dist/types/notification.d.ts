/**
 * Notification type
 */
export declare enum NotificationType {
    SYSTEM = "system",
    NODE = "node",
    BLOCKCHAIN = "blockchain",
    SECURITY = "security",
    USER = "user"
}
/**
 * Notification priority
 */
export declare enum NotificationPriority {
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high",
    CRITICAL = "critical"
}
/**
 * Notification status
 */
export declare enum NotificationStatus {
    UNREAD = "unread",
    READ = "read",
    ARCHIVED = "archived"
}
/**
 * Notification channel
 */
export declare enum NotificationChannel {
    IN_APP = "in_app",
    EMAIL = "email",
    SMS = "sms",
    WEBHOOK = "webhook",
    SLACK = "slack",
    TELEGRAM = "telegram",
    DISCORD = "discord"
}
/**
 * Notification
 */
export interface Notification {
    id: string;
    userId: string;
    type: NotificationType;
    priority: NotificationPriority;
    title: string;
    message: string;
    status: NotificationStatus;
    createdAt: string;
    readAt?: string;
    data?: any;
    actions?: NotificationAction[];
}
/**
 * Notification action
 */
export interface NotificationAction {
    label: string;
    action: string;
    url?: string;
    data?: any;
}
/**
 * Notification template
 */
export interface NotificationTemplate {
    id: string;
    name: string;
    type: NotificationType;
    title: string;
    message: string;
    channels: NotificationChannel[];
    variables: string[];
    createdAt: string;
    updatedAt: string;
}
/**
 * Notification settings
 */
export interface NotificationSettings {
    userId: string;
    channels: {
        [NotificationChannel.IN_APP]: boolean;
        [NotificationChannel.EMAIL]: boolean;
        [NotificationChannel.SMS]: boolean;
        [NotificationChannel.WEBHOOK]?: boolean;
        [NotificationChannel.SLACK]?: boolean;
        [NotificationChannel.TELEGRAM]?: boolean;
        [NotificationChannel.DISCORD]?: boolean;
    };
    preferences: {
        [NotificationType.SYSTEM]: NotificationPriority[];
        [NotificationType.NODE]: NotificationPriority[];
        [NotificationType.BLOCKCHAIN]: NotificationPriority[];
        [NotificationType.SECURITY]: NotificationPriority[];
        [NotificationType.USER]: NotificationPriority[];
    };
    schedules: {
        quietHoursEnabled: boolean;
        quietHoursStart?: string;
        quietHoursEnd?: string;
        timezone: string;
        workDays: number[];
    };
    contacts: {
        email?: string;
        phone?: string;
        webhook?: string;
        slack?: string;
        telegram?: string;
        discord?: string;
    };
}
/**
 * Alert rule
 */
export interface AlertRule {
    id: string;
    name: string;
    description?: string;
    enabled: boolean;
    type: NotificationType;
    condition: {
        metric: string;
        operator: '>' | '>=' | '=' | '<=' | '<' | '!=';
        value: number | string;
        duration?: number;
    };
    priority: NotificationPriority;
    channels: NotificationChannel[];
    cooldown: number;
    createdAt: string;
    updatedAt: string;
    lastTriggered?: string;
}
/**
 * Alert history
 */
export interface AlertHistory {
    id: string;
    ruleId: string;
    ruleName: string;
    triggered: string;
    resolved?: string;
    value: number | string;
    threshold: number | string;
    priority: NotificationPriority;
    notificationsSent: number;
    recipients: string[];
}
