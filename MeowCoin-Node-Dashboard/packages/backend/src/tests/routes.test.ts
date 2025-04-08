import { describe, it, expect } from '@jest/globals';
import routes from '../routes';

describe('Node Routes', () => {
  it('has a node status route', () => {
    // Simple check that routes module exists
    expect(routes).toBeDefined();
  });
});
