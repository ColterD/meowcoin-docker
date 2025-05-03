/**
 * Notification type
 */
// eslint-disable-next-line no-unused-vars
export enum NotificationType {
  SYSTEM = 'system',
  NODE = 'node',
  BLOCKCHAIN = 'blockchain',
  SECURITY = 'security',
  USER = 'user',
}

/**
 * Notification priority
 */
// eslint-disable-next-line no-unused-vars
export enum NotificationPriority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

/**
 * Notification status
 */
// eslint-disable-next-line no-unused-vars
export enum NotificationStatus {
  UNREAD = 'unread',
  READ = 'read',
  ARCHIVED = 'archived',
}

/**
 * Notification channel
 */
// eslint-disable-next-line no-unused-vars
export enum NotificationChannel {
  IN_APP = 'in_app',
  EMAIL = 'email',
  SMS = 'sms',
  WEBHOOK = 'webhook',
  SLACK = 'slack',
  TELEGRAM = 'telegram',
  DISCORD = 'discord',
}

// Structured notification data
export interface NotificationData<T = unknown> {
  [key: string]: T | undefined;
}

// Structured notification action data
export interface NotificationActionData<T = unknown> {
  [key: string]: T | undefined;
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
  createdAt: string; // ISO date string
  readAt?: string; // ISO date string
  data?: NotificationData;
  actions?: NotificationAction[];
}

/**
 * Notification action
 */
export interface NotificationAction {
  label: string;
  action: string;
  url?: string;
  data?: NotificationActionData;
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
  createdAt: string; // ISO date string
  updatedAt: string; // ISO date string
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
    quietHoursStart?: string; // HH:MM in 24-hour format
    quietHoursEnd?: string; // HH:MM in 24-hour format
    timezone: string;
    workDays: number[]; // 0-6, where 0 is Sunday
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
    duration?: number; // seconds
  };
  priority: NotificationPriority;
  channels: NotificationChannel[];
  cooldown: number; // seconds
  createdAt: string; // ISO date string
  updatedAt: string; // ISO date string
  lastTriggered?: string; // ISO date string
}

/**
 * Alert history
 */
export interface AlertHistory {
  id: string;
  ruleId: string;
  ruleName: string;
  triggered: string; // ISO date string
  resolved?: string; // ISO date string
  value: number | string;
  threshold: number | string;
  priority: NotificationPriority;
  notificationsSent: number;
  recipients: string[];
}