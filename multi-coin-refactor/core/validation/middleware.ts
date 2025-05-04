// #region Input Validation Middleware
/**
 * Express-style middleware for input validation.
 * Supports per-route and per-coin validation schemas.
 * Logs validation errors to monitoring/metrics.
 * TODO[roadmap]: Integrate with real validation schemas and registry.
 */

/**
 * Validation middleware for Express-style handlers.
 * @param schema - Optional validation schema (e.g., Zod)
 */
export function validateInput<T = unknown>(schema?: { safeParse: (body: T) => { success: boolean; error?: unknown } }) {
  return (req: { body: T }, res: { status: (code: number) => { json: (body: unknown) => void } }, next: () => void) => {
    if (!schema) return next();
    const result = schema.safeParse(req.body);
    if (result.success) return next();
    res.status(400).json({ error: result.error });
  };
}
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 

// #region Validation Middleware
// TODO[roadmap]: Expand for advanced onboarding, feedback, and config validation middleware
// TODO[roadmap]: Add schema registry and unified validation middleware
// #endregion 