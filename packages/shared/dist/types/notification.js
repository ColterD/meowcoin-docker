"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationChannel = exports.NotificationStatus = exports.NotificationPriority = exports.NotificationType = void 0;
/**
 * Notification type
 */
var NotificationType;
(function (NotificationType) {
    NotificationType["SYSTEM"] = "system";
    NotificationType["NODE"] = "node";
    NotificationType["BLOCKCHAIN"] = "blockchain";
    NotificationType["SECURITY"] = "security";
    NotificationType["USER"] = "user";
})(NotificationType || (exports.NotificationType = NotificationType = {}));
/**
 * Notification priority
 */
var NotificationPriority;
(function (NotificationPriority) {
    NotificationPriority["LOW"] = "low";
    NotificationPriority["MEDIUM"] = "medium";
    NotificationPriority["HIGH"] = "high";
    NotificationPriority["CRITICAL"] = "critical";
})(NotificationPriority || (exports.NotificationPriority = NotificationPriority = {}));
/**
 * Notification status
 */
var NotificationStatus;
(function (NotificationStatus) {
    NotificationStatus["UNREAD"] = "unread";
    NotificationStatus["READ"] = "read";
    NotificationStatus["ARCHIVED"] = "archived";
})(NotificationStatus || (exports.NotificationStatus = NotificationStatus = {}));
/**
 * Notification channel
 */
var NotificationChannel;
(function (NotificationChannel) {
    NotificationChannel["IN_APP"] = "in_app";
    NotificationChannel["EMAIL"] = "email";
    NotificationChannel["SMS"] = "sms";
    NotificationChannel["WEBHOOK"] = "webhook";
    NotificationChannel["SLACK"] = "slack";
    NotificationChannel["TELEGRAM"] = "telegram";
    NotificationChannel["DISCORD"] = "discord";
})(NotificationChannel || (exports.NotificationChannel = NotificationChannel = {}));
