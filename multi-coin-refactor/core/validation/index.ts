// If you see linter errors for 'zod', run: npm i zod

// #region Validation Schemas
/**
 * Shared validation schemas for wallet addresses and coins.
 * Used by onboarding, API, and wizard modules.
 * TODO[roadmap]: Add schemas for all supported coins.
 */
import * as z from 'zod';

export const walletAddressSchema = z.string().min(26).max(35); // Example: Bitcoin-like address

export const bitcoinAddressSchema = z.string().regex(/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/); // Simplified Bitcoin address regex

// Feedback schema: feedback (required string), createdAt (required ISO string), userId/context (optional)
export const feedbackSchema = z.object({
  feedback: z.string().min(1),
  createdAt: z.string().refine(v => !isNaN(Date.parse(v)), { message: 'Invalid date' }),
  userId: z.string().optional(),
  context: z.string().optional()
});

// Onboarding schema: coin (required string), config (required object), createdAt (required ISO string), advanced (optional object)
export const onboardingSchema = z.object({
  coin: z.string().min(1),
  config: z.record(z.unknown()),
  createdAt: z.string().refine(v => !isNaN(Date.parse(v)), { message: 'Invalid date' }),
  advanced: z.record(z.unknown()).optional()
});

export const validationSchemas = {
  walletAddress: walletAddressSchema,
  bitcoinAddress: bitcoinAddressSchema,
  feedback: feedbackSchema,
  onboarding: onboardingSchema
};
// #endregion

// #region Validation Entry Point
// TODO[roadmap]: Expand for advanced onboarding, feedback, and config validation
// TODO[roadmap]: Add schema registry and unified validation
// #endregion 