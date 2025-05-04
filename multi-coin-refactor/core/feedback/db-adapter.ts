// #region DB Feedback Adapter
/**
 * Database adapter for feedback persistence.
 * Implements the StorageAdapter interface for UserFeedback.
 * Uses SQLite for storage via better-sqlite3.
 */
import { StorageAdapter } from '../types';
import { UserFeedback } from './index';
import { recordMetric } from '../monitoring';
import * as path from 'path';

// Dynamic import for better-sqlite3 to avoid issues in browser environments
let Database: any;
try {
  Database = require('better-sqlite3');
} catch (e) {
  console.warn('better-sqlite3 not available, DB feedback adapter will not work');
}

const DB_PATH = path.resolve(process.cwd(), 'data/feedback.db');

/**
 * SQLite-based feedback storage adapter.
 * Implements the StorageAdapter interface for UserFeedback.
 */
export class DBFeedbackAdapter implements StorageAdapter<UserFeedback> {
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
        data: { error: 'Failed to initialize feedback database', details: error },
        timestamp: new Date().toISOString(),
      });
      throw new Error(`Failed to initialize feedback database: ${error?.message || String(error)}`);
    }
  }

  /**
   * Initialize the database schema if it doesn't exist.
   */
  private initializeDatabase() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        feedback TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        context TEXT
      )
    `);
  }

  /**
   * Save a feedback item to the database.
   * @param item - The feedback item to save
   */
  async save(item: UserFeedback): Promise<void> {
    try {
      const stmt = this.db.prepare(`
        INSERT INTO feedback (userId, feedback, createdAt, context)
        VALUES (?, ?, ?, ?)
      `);
      
      stmt.run(
        item.userId || null,
        item.feedback,
        item.createdAt,
        item.context || null
      );
      
      recordMetric({
        type: 'feedback',
        data: { action: 'save', storage: 'db', item },
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to save feedback to database', item, details: error },
        timestamp: new Date().toISOString(),
      });
      throw new Error(`Failed to save feedback to database: ${error?.message || String(error)}`);
    }
  }

  /**
   * Get all feedback items from the database.
   * @returns Array of feedback items
   */
  async getAll(): Promise<UserFeedback[]> {
    try {
      const stmt = this.db.prepare('SELECT userId, feedback, createdAt, context FROM feedback');
      const rows = stmt.all();
      
      recordMetric({
        type: 'feedback',
        data: { action: 'getAll', storage: 'db', count: rows.length },
        timestamp: new Date().toISOString(),
      });
      
      return rows.map((row: any) => ({
        userId: row.userId || undefined,
        feedback: row.feedback,
        createdAt: row.createdAt,
        context: row.context || undefined,
      }));
    } catch (error) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to get feedback from database', details: error },
        timestamp: new Date().toISOString(),
      });
      return [];
    }
  }

  /**
   * Clear all feedback items from the database.
   */
  async clear(): Promise<void> {
    try {
      this.db.prepare('DELETE FROM feedback').run();
      
      recordMetric({
        type: 'feedback',
        data: { action: 'clear', storage: 'db' },
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      recordMetric({
        type: 'error',
        data: { error: 'Failed to clear feedback from database', details: error },
        timestamp: new Date().toISOString(),
      });
      throw new Error(`Failed to clear feedback from database: ${error?.message || String(error)}`);
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