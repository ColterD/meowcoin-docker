// #region DB Onboarding Adapter
/**
 * Database adapter for onboarding configuration persistence.
 * Implements the StorageAdapter interface for OnboardingConfig.
 * Uses SQLite for storage via better-sqlite3.
 */
import { StorageAdapter } from '../types';
import { OnboardingConfig } from './configStore';
import { recordMetric } from '../monitoring';
import * as path from 'path';

// Dynamic import for better-sqlite3 to avoid issues in browser environments
let Database: any;
try {
  Database = require('better-sqlite3');
} catch (e) {
  console.warn('better-sqlite3 not available, DB onboarding adapter will not work');
}

const DB_PATH = path.resolve(process.cwd(), 'data/onboarding.db');

/**
 * SQLite-based onboarding configuration storage adapter.
 * Implements the StorageAdapter interface for OnboardingConfig.
 */
export class DBOnboardingAdapter implements StorageAdapter<OnboardingConfig> {
  private db: any;

  constructor() {
    if (!Database) {
      throw new Error('better-sqlite3 is not available');
    }

    try {
      this.db = new Database(DB_PATH);
      this.initializeDatabase();
    } catch (error: any) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to initialize onboarding database', details: error },
        timestamp: new Date().toISOString(),
      });
      throw new Error(`Failed to initialize onboarding database: ${error?.message || String(error)}`);
    }
  }

  /**
   * Initialize the database schema if it doesn't exist.
   */
  private initializeDatabase() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS onboarding (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        coin TEXT NOT NULL,
        config TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        advanced TEXT
      )
    `);
  }

  /**
   * Save an onboarding configuration to the database.
   * @param item - The onboarding configuration to save
   */
  async save(item: OnboardingConfig): Promise<void> {
    try {
      const stmt = this.db.prepare(`
        INSERT INTO onboarding (coin, config, createdAt, advanced)
        VALUES (?, ?, ?, ?)
      `);
      
      stmt.run(
        item.coin,
        JSON.stringify(item.config),
        item.createdAt,
        item.advanced ? JSON.stringify(item.advanced) : null
      );
      
      recordMetric({
        type: 'onboarding',
        data: { action: 'save', storage: 'db', item },
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to save onboarding config to database', item, details: error },
        timestamp: new Date().toISOString(),
      });
      throw new Error(`Failed to save onboarding config to database: ${error?.message || String(error)}`);
    }
  }

  /**
   * Get all onboarding configurations from the database.
   * @returns Array of onboarding configurations
   */
  async getAll(): Promise<OnboardingConfig[]> {
    try {
      const stmt = this.db.prepare('SELECT coin, config, createdAt, advanced FROM onboarding');
      const rows = stmt.all();
      
      recordMetric({
        type: 'onboarding',
        data: { action: 'getAll', storage: 'db', count: rows.length },
        timestamp: new Date().toISOString(),
      });
      
      return rows.map((row: any) => ({
        coin: row.coin,
        config: JSON.parse(row.config),
        createdAt: row.createdAt,
        advanced: row.advanced ? JSON.parse(row.advanced) : undefined,
      }));
    } catch (error) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to get onboarding configs from database', details: error },
        timestamp: new Date().toISOString(),
      });
      return [];
    }
  }

  /**
   * Get an onboarding configuration by coin.
   * @param coin - The coin symbol
   * @returns The onboarding configuration or null if not found
   */
  async getByCoin(coin: string): Promise<OnboardingConfig | null> {
    try {
      const stmt = this.db.prepare('SELECT coin, config, createdAt, advanced FROM onboarding WHERE coin = ? ORDER BY id DESC LIMIT 1');
      const row = stmt.get(coin);
      
      if (!row) {
        return null;
      }
      
      recordMetric({
        type: 'onboarding',
        data: { action: 'getByCoin', storage: 'db', coin },
        timestamp: new Date().toISOString(),
      });
      
      return {
        coin: row.coin,
        config: JSON.parse(row.config),
        createdAt: row.createdAt,
        advanced: row.advanced ? JSON.parse(row.advanced) : undefined,
      };
    } catch (error) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to get onboarding config by coin from database', coin, details: error },
        timestamp: new Date().toISOString(),
      });
      return null;
    }
  }

  /**
   * Clear all onboarding configurations from the database.
   */
  async clear(): Promise<void> {
    try {
      this.db.prepare('DELETE FROM onboarding').run();
      
      recordMetric({
        type: 'onboarding',
        data: { action: 'clear', storage: 'db' },
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to clear onboarding configs from database', details: error },
        timestamp: new Date().toISOString(),
      });
      throw new Error(`Failed to clear onboarding configs from database: ${error?.message || String(error)}`);
    }
  }

  /**
   * Close the database connection.
   */
  close(): void {
    if (this.db) {
      this.db.close();
    }
  }
}
// #endregion