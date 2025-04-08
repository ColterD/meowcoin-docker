import nodeManager from '../nodeManager';
import { NodeStatus } from '@meowcoin/shared';

describe('NodeManager', () => {
  it('initializes with default nodes', () => {
    const nodes = nodeManager.getStatus();
    expect(nodes.length).toBeGreaterThan(0);
    expect(nodes[0]).toHaveProperty('id');
  });

  it('updates node status', () => {
    const node = nodeManager.updateNode('node1', 'stop');
    expect(node.status).toBe('stopped');
  });
});
