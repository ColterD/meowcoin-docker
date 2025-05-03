"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("./config");
const server_1 = require("./server");
const logger_1 = require("./utils/logger");
async function start() {
    try {
        const server = await (0, server_1.buildServer)();
        await server.listen({
            port: config_1.config.port,
            host: '0.0.0.0'
        });
        logger_1.logger.info(`Server listening on ${config_1.config.port}`);
        // Handle graceful shutdown
        const shutdown = async () => {
            logger_1.logger.info('Shutting down server...');
            await server.close();
            process.exit(0);
        };
        process.on('SIGTERM', shutdown);
        process.on('SIGINT', shutdown);
    }
    catch (err) {
        logger_1.logger.error(err, 'Error starting server');
        process.exit(1);
    }
}
start();
