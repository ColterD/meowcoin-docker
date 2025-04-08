import express from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { AppError, ErrorCodes, TOKEN_EXPIRY } from '@meowcoin/shared';
import configService from '../config';

const router = express.Router();

const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

router.post('/login', (req, res) => {
  try {
    // Validate request body
    const { username, password } = loginSchema.parse(req.body);
    
    // In a real app, you would check against a database
    // This is a simplified example with a hardcoded admin user
    if (username === 'admin' && password === 'meowcoin') {
      const token = jwt.sign(
        { 
          id: '1', 
          username: 'admin', 
          role: 'admin' 
        }, 
        configService.jwtSecret,
        { expiresIn: TOKEN_EXPIRY }
      );
      
      res.json({ 
        success: true, 
        data: { 
          token,
          user: {
            username: 'admin',
            role: 'admin'
          } 
        } 
      });
    } else {
      throw new AppError(ErrorCodes.UNAUTHORIZED, 'Invalid credentials', 401);
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'Username and password are required',
        400
      );
    }
    
    if (error instanceof AppError) {
      throw error;
    }
    
    throw new AppError(ErrorCodes.INTERNAL_ERROR, 'Login failed', 500);
  }
});

export default router;