"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NodeType = exports.NodeAction = exports.NodeStatus = void 0;
/**
 * Node status types
 */
var NodeStatus;
(function (NodeStatus) {
    NodeStatus["RUNNING"] = "running";
    NodeStatus["STARTING"] = "starting";
    NodeStatus["STOPPING"] = "stopping";
    NodeStatus["STOPPED"] = "stopped";
    NodeStatus["SYNCING"] = "syncing";
    NodeStatus["ERROR"] = "error";
    NodeStatus["UNKNOWN"] = "unknown";
})(NodeStatus || (exports.NodeStatus = NodeStatus = {}));
/**
 * Node action types
 */
var NodeAction;
(function (NodeAction) {
    NodeAction["START"] = "start";
    NodeAction["STOP"] = "stop";
    NodeAction["RESTART"] = "restart";
    NodeAction["BACKUP"] = "backup";
    NodeAction["RESTORE"] = "restore";
    NodeAction["UPDATE"] = "update";
    NodeAction["RESET"] = "reset";
})(NodeAction || (exports.NodeAction = NodeAction = {}));
/**
 * Node type
 */
var NodeType;
(function (NodeType) {
    NodeType["FULL_NODE"] = "full_node";
    NodeType["MINING_NODE"] = "mining_node";
    NodeType["ARCHIVE_NODE"] = "archive_node";
    NodeType["LIGHT_NODE"] = "light_node";
    NodeType["VALIDATOR_NODE"] = "validator_node";
})(NodeType || (exports.NodeType = NodeType = {}));
