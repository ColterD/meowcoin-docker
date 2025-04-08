import { getConfig, EnvironmentConfig, getDefaultPort } from '@meowcoin/shared';

export class ConfigService {
  private config: EnvironmentConfig;

  constructor() {
    this.config = getConfig();
  }

  get port(): number {
    return getDefaultPort();
  }

  get apiKey(): string {
    return this.config.nodeApiKey;
  }

  get syncInterval(): number {
    return this.config.syncInterval;
  }

  get jwtSecret(): string {
    return this.config.jwtSecret;
  }

  get maxConnections(): number {
    return this.config.maxConnections;
  }

  updateConfig(newConfig: Partial<EnvironmentConfig>): void {
    this.config = { ...this.config, ...newConfig };
  }
}

export default new ConfigService();