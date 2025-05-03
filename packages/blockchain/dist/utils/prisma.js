"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = void 0;
const client_1 = require("@prisma/client");
const logger_1 = require("./logger");
// Create Prisma client instance
exports.prisma = new client_1.PrismaClient({
    log: [
        {
            emit: 'event',
            level: 'query',
        },
        {
            emit: 'event',
            level: 'error',
        },
        {
            emit: 'event',
            level: 'info',
        },
        {
            emit: 'event',
            level: 'warn',
        },
    ],
});
// Log Prisma queries in development
if (process.env.NODE_ENV === 'development') {
    exports.prisma.$on('query', (e) => {
        logger_1.logger.debug(`Query: ${e.query}`);
        logger_1.logger.debug(`Duration: ${e.duration}ms`);
    });
}
// Log Prisma errors
exports.prisma.$on('error', (e) => {
    logger_1.logger.error(e, 'Prisma error');
});
// Handle Prisma connection
exports.prisma.$connect()
    .then(() => {
    logger_1.logger.info('Connected to database');
})
    .catch((error) => {
    logger_1.logger.error(error, 'Failed to connect to database');
    process.exit(1);
});
// Handle process exit
process.on('beforeExit', async () => {
    await exports.prisma.$disconnect();
    logger_1.logger.info('Disconnected from database');
});
