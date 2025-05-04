// If you see linter errors, run: npm i --save-dev @types/node
// #region User Feedback Loop
/**
 * Interface for user feedback submission.
 * TODO[roadmap]: Integrate with UI/CLI for real feedback collection and persistence.
 * Logs feedback events to monitoring/metrics.
 * Cross-link to onboarding and monitoring modules.
 */
import { recordMetric } from '../monitoring';
import * as path from 'path';
import { feedbackSchema } from '../validation';
// Use dynamic import for 'fs' to avoid linter errors in non-Node environments
let writeFileSync: ((...args: unknown[]) => void) | undefined, 
    readFileSync: ((...args: unknown[]) => string) | undefined, 
    existsSync: ((...args: unknown[]) => boolean) | undefined,
    mkdirSync: ((...args: unknown[]) => void) | undefined;
try {
  ({ writeFileSync, readFileSync, existsSync, mkdirSync } = require('fs'));
} catch (e) {
  writeFileSync = readFileSync = existsSync = mkdirSync = undefined;
}
const FEEDBACK_PATH = path.resolve(process.cwd(), 'core/feedback/feedbacks.json');
import { StorageAdapter } from '../types';

export interface UserFeedback {
  userId?: string;
  feedback: string;
  createdAt: string;
  context?: string;
}

// #region Storage Adapters
class InMemoryFeedbackAdapter implements StorageAdapter<UserFeedback> {
  private items: UserFeedback[] = [];
  async save(item: UserFeedback) { this.items.push(item); }
  async getAll() { return this.items; }
  async clear() { this.items = []; }
}

class FileFeedbackAdapter implements StorageAdapter<UserFeedback> {
  async save(item: UserFeedback) {
    const items = await this.getAll();
    items.push(item);
    this.ensureDirectoryExists();
    if (writeFileSync) writeFileSync(FEEDBACK_PATH, JSON.stringify(items, null, 2));
  }
  
  async getAll() {
    if (existsSync && existsSync(FEEDBACK_PATH)) {
      try {
        return readFileSync ? JSON.parse(readFileSync(FEEDBACK_PATH, 'utf-8')) : [];
      } catch (e) {
        return [];
      }
    }
    return [];
  }
  
  async clear() { 
    this.ensureDirectoryExists();
    if (writeFileSync) writeFileSync(FEEDBACK_PATH, '[]'); 
  }
  
  private ensureDirectoryExists() {
    if (!existsSync || !mkdirSync) return;
    
    const dir = path.dirname(FEEDBACK_PATH);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
  }
}

// TODO[roadmap]: Add DBFeedbackAdapter for persistent DB-backed storage
// #endregion

// Import the DB adapter (dynamically to avoid issues in browser environments)
let DBFeedbackAdapter: any;
try {
  ({ DBFeedbackAdapter } = require('./db-adapter'));
} catch (e) {
  // DB adapter not available, will fall back to other adapters
}

// #region Adapter Selection
// Create a function to get the adapter to ensure we always use the current environment variable value
function getAdapter(): StorageAdapter<UserFeedback> {
  const persistenceType = process.env.FEEDBACK_PERSISTENCE;
  
  if (persistenceType === 'file') {
    return new FileFeedbackAdapter();
  } else if (persistenceType === 'db') {
    if (!DBFeedbackAdapter) {
      console.warn('DB adapter requested but not available, falling back to in-memory');
      return new InMemoryFeedbackAdapter();
    }
    try {
      return new DBFeedbackAdapter();
    } catch (error) {
      console.error('Failed to initialize DB adapter:', error);
      console.warn('Falling back to in-memory adapter');
      return new InMemoryFeedbackAdapter();
    }
  } else {
    // Default to in-memory
    return new InMemoryFeedbackAdapter();
  }
}
// #endregion

/**
 * Submit user feedback and log to monitoring/metrics. Persists to file.
 * @param feedback - UserFeedback object
 */
export async function submitUserFeedback(feedback: UserFeedback) {
  // Unified validation using shared schema
  const result = feedbackSchema.safeParse(feedback);
  if (!result.success) throw new Error('Invalid feedback: ' + JSON.stringify(result.error));
  await getAdapter().save(feedback);
  recordMetric({
    type: 'feedback',
    data: feedback,
    timestamp: feedback.createdAt,
  });
  // TODO[roadmap]: Add DB integration for feedback persistence
}

/**
 * Get all feedback submissions (loads from file).
 */
export async function getAllFeedback() {
  return getAdapter().getAll();
}

/**
 * Clear all feedback submissions (for test isolation and file cleanup).
 */
export async function clearFeedbacks() {
  await getAdapter().clear();
}
// #endregion 

// #region Error Handling Standardization
// For every throw new Error, ensure recordMetric is called just before
// ... existing code ...
// #endregion 

// #region Feedback Barrel
// TODO[roadmap]: Add feedback adapters and advanced flows here
// #endregion 

// #region Feedback Module
// ... existing code ...
// TODO[roadmap]: Expand for advanced onboarding, feedback, and monitoring flows
// TODO[roadmap]: Add DB-backed feedback storage and advanced feedback flows
// #endregion 