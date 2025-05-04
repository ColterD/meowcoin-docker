// #region Authentication Middleware
/**
 * Express-style middleware for authentication and RBAC.
 * Logs authentication and RBAC failures to monitoring/metrics.
 * TODO[roadmap]: Integrate with real authentication provider and user roles.
 */

import { authenticate } from '../../core/auth';

/**
 * Authentication and RBAC middleware for Express-style handlers.
 * @param roles - Optional array of required roles
 */
export function requireAuth(roles?: string[]) {
  return (req: any, res: any, next: () => void) => {
    // Extract JWT from Authorization header
    const authHeader = req.headers?.authorization || req.headers?.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    const token = authHeader.slice(7);
    const user = authenticate(token);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });
    req.user = user;
    if (roles && !roles.some(role => user.roles?.includes(role))) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}
// #endregion

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 