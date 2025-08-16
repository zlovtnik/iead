import { z } from 'zod';

/**
 * Validation utilities for form handling and error formatting
 */

export interface ValidationError {
  field: string;
  message: string;
  code: string;
}

export interface FormErrors {
  [key: string]: string;
}

/**
 * Formats Zod validation errors into a user-friendly format
 */
export function formatZodErrors(error: z.ZodError): FormErrors {
  const errors: FormErrors = {};
  
  // Handle both direct ZodError and safeParse error result
  const issues = error.issues || error.errors || [];
  
  if (Array.isArray(issues)) {
    issues.forEach((err: any) => {
      const field = err.path ? err.path.join('.') : '_general';
      errors[field] = err.message;
    });
  }
  
  return errors;
}

/**
 * Formats API validation errors into form errors
 */
export function formatApiErrors(apiError: any): FormErrors {
  const errors: FormErrors = {};
  
  if (apiError?.details) {
    Object.entries(apiError.details).forEach(([field, messages]) => {
      if (Array.isArray(messages) && messages.length > 0) {
        errors[field] = messages[0];
      }
    });
  } else if (apiError?.message) {
    errors._general = apiError.message;
  }
  
  return errors;
}

/**
 * Validates a single field value against a schema
 */
export function validateField<T>(
  schema: z.ZodSchema<T>,
  value: any,
  fieldName: string
): string | null {
  try {
    schema.parse(value);
    return null;
  } catch (error) {
    if (error instanceof z.ZodError) {
      const issues = error.issues || error.errors || [];
      if (Array.isArray(issues)) {
        const fieldError = issues.find((err: any) => 
          !err.path || err.path.length === 0 || err.path[0] === fieldName
        );
        return fieldError?.message || 'Invalid value';
      }
    }
    return 'Validation error';
  }
}

/**
 * Debounced validation function
 */
export function createDebouncedValidator<T>(
  schema: z.ZodSchema<T>,
  callback: (errors: FormErrors | null) => void,
  delay: number = 300
) {
  let timeoutId: number;
  
  return (data: any) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      try {
        schema.parse(data);
        callback(null);
      } catch (error) {
        if (error instanceof z.ZodError) {
          callback(formatZodErrors(error));
        } else {
          callback({ _general: 'Validation error' });
        }
      }
    }, delay);
  };
}

/**
 * Common validation schemas
 */
export const commonValidators = {
  email: z.string().email('Please enter a valid email address'),
  phone: z.string().regex(/^\+?[\d\s\-\(\)]+$/, 'Please enter a valid phone number').optional(),
  required: (message = 'This field is required') => z.string().min(1, message),
  positiveNumber: z.number().positive('Must be a positive number'),
  currency: z.number().min(0, 'Amount must be zero or greater').multipleOf(0.01, 'Amount must have at most 2 decimal places'),
};