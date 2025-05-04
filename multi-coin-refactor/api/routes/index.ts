// #region API Routes
/**
 * Registers API routes for all enabled coins.
 * Used by the main API server to expose coin-agnostic endpoints.
 * TODO[roadmap]: Add more endpoints and error handling as needed.
 */
import { getEnabledCoins } from '../../core/registry';
import { CoinModule } from '../../core/types';
import { walletAddressSchema } from '../../core/validation';

// Example: Register a route for each enabled coin
export function getApiRoutes() {
  const coins = getEnabledCoins();
  return coins.map((coin: CoinModule) => ({
    path: `/api/${coin.metadata.symbol.toLowerCase()}/balance`,
    method: 'GET',
    handler: async (req: { query: { address: string } }) => {
      const { address } = req.query;
      // Unified validation using shared schema
      const result = walletAddressSchema.safeParse(address);
      if (!result.success) {
        return { status: 400, body: { error: 'Invalid address', details: result.error } };
      }
      // Type assertion for getBalance function
      const getBalance = coin.rpc.getBalance as (address: string) => Promise<unknown>;
      const balance = await getBalance(address);
      return { status: 200, body: { balance } };
    }
  }));
}
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring endpoints
// TODO[roadmap]: Add OpenAPI/Swagger integration
// #endregion 