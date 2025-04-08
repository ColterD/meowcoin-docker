import { AppError, ErrorCodes, isAppError } from '@meowcoin/shared';

// Convert any error to AppError
export const handleError = (error: unknown): AppError => {
  if (isAppError(error)) {
    return error;
  }
  
  if (error instanceof Error) {
    return new AppError(
      ErrorCodes.INTERNAL_ERROR,
      error.message || 'An unexpected error occurred',
      500
    );
  }
  
  return new AppError(
    ErrorCodes.UNKNOWN_ERROR,
    'An unknown error occurred',
    500
  );
};

// Get user-friendly error message
export const getUserFriendlyMessage = (error: AppError): string => {
  // Default message is the error message itself
  let message = error.message;
  
  // Customize based on error code
  switch (error.code) {
    case ErrorCodes.NETWORK_ERROR:
      message = 'Unable to connect to the server. Please check your internet connection and try again.';
      break;
    case ErrorCodes.UNAUTHORIZED:
      message = 'You need to log in to access this feature.';
      break;
    case ErrorCodes.FORBIDDEN:
      message = 'You do not have permission to perform this action.';
      break;
    case ErrorCodes.NODE_UNAVAILABLE:
      message = 'The node is currently unavailable. Please try again later.';
      break;
    case ErrorCodes.VALIDATION_ERROR:
      // Keep the original message as it should have details
      break;
    case ErrorCodes.INTERNAL_ERROR:
      message = 'An internal server error occurred. Please try again later or contact support.';
      break;
    default:
      message = 'An unexpected error occurred. Please try again later.';
  }
  
  return message;
};

// Log error to console (could be extended to use a monitoring service)
export const logError = (error: unknown, context?: string): void => {
  const appError = handleError(error);
  
  console.error(
    `[Error${context ? ` - ${context}` : ''}] ${appError.code}: ${appError.message}`,
    error
  );
};