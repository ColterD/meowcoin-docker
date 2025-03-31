// backend/src/__tests__/nodeController.test.ts
import { Request, Response } from 'express';
import { getStatus } from '../controllers/nodeController';
import * as nodeService from '../services/nodeService';

// Properly mock the nodeService module
jest.mock('../services/nodeService', () => ({
  getNodeStatus: jest.fn()
}));

describe('nodeController', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let jsonMock: jest.Mock;
  let statusMock: jest.Mock;

  beforeEach(() => {
    jsonMock = jest.fn();
    statusMock = jest.fn().mockReturnValue({ json: jsonMock });
    
    mockRequest = {};
    mockResponse = {
      status: statusMock,
      json: jsonMock,
    };
    
    // Clear all mocks before each test
    jest.clearAllMocks();
  });

  describe('getStatus', () => {
    it('should return node status on success', async () => {
      // Mock successful response
      const mockStatus = { status: 'running' };
      (nodeService.getNodeStatus as jest.Mock).mockResolvedValue(mockStatus);

      await getStatus(mockRequest as Request, mockResponse as Response);

      expect(jsonMock).toHaveBeenCalledWith(mockStatus);
      expect(statusMock).not.toHaveBeenCalled();
    });

    it('should return 500 when status is null', async () => {
      // Mock null response
      (nodeService.getNodeStatus as jest.Mock).mockResolvedValue(null);

      await getStatus(mockRequest as Request, mockResponse as Response);

      expect(statusMock).toHaveBeenCalledWith(500);
      expect(jsonMock).toHaveBeenCalledWith({ 
        success: false, 
        message: 'Failed to get node status' 
      });
    });

    it('should handle errors', async () => {
      // Mock error
      const error = new Error('Test error');
      (nodeService.getNodeStatus as jest.Mock).mockRejectedValue(error);

      await getStatus(mockRequest as Request, mockResponse as Response);

      expect(statusMock).toHaveBeenCalledWith(500);
      expect(jsonMock).toHaveBeenCalledWith({ 
        success: false, 
        message: 'Error in getStatus controller: Test error' 
      });
    });
  });
});