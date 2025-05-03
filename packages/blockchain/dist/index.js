"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const logger_1 = require("./utils/logger");
const nodeManager_1 = require("./services/nodeManager");
async function start() {
    try {
        // Initialize node manager
        await (0, nodeManager_1.initializeNodeManager)();
        // No server to start; buildServer is missing
        logger_1.logger.info(`Blockchain service initialized (no server started)`);
        // No graceful shutdown needed
    }
    catch (err) {
        logger_1.logger.error(err, 'Error starting blockchain service');
        process.exit(1);
    }
}
start();
