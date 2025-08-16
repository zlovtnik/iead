import { describe, it, expect, vi } from 'vitest';
import { z } from 'zod';
import {
  formatZodErrors,
  formatApiErrors,
  validateField,
  createDebouncedValidator,
  commonValidators
} from './validation.js';

describe('validation utilities', () => {
  describe('formatZodErrors', () => {
    it('formats single field error', () => {
      const schema = z.object({
        name: z.string().min(1, 'Name is required')
      });

      const result = schema.safeParse({ name: '' });
      if (!result.success) {
        const formatted = formatZodErrors(result.error);
        expect(formatted).toEqual({ name: 'Name is required' });
      } else {
        throw new Error('Expected validation to fail');
      }
    });

    it('formats multiple field errors', () => {
      const schema = z.object({
        name: z.string().min(1, 'Name is required'),
        email: z.string().email('Invalid email')
      });

      const result = schema.safeParse({ name: '', email: 'invalid' });
      if (!result.success) {
        const formatted = formatZodErrors(result.error);
        expect(formatted).toEqual({
          name: 'Name is required',
          email: 'Invalid email'
        });
      } else {
        throw new Error('Expected validation to fail');
      }
    });

    it('formats nested field errors', () => {
      const schema = z.object({
        user: z.object({
          name: z.string().min(1, 'Name is required')
        })
      });

      const result = schema.safeParse({ user: { name: '' } });
      if (!result.success) {
        const formatted = formatZodErrors(result.error);
        expect(formatted).toEqual({ 'user.name': 'Name is required' });
      } else {
        throw new Error('Expected validation to fail');
      }
    });
  });

  describe('formatApiErrors', () => {
    it('formats API errors with details', () => {
      const apiError = {
        message: 'Validation failed',
        details: {
          name: ['Name is required'],
          email: ['Email is invalid', 'Email already exists']
        }
      };

      const formatted = formatApiErrors(apiError);
      expect(formatted).toEqual({
        name: 'Name is required',
        email: 'Email is invalid'
      });
    });

    it('formats API errors with general message', () => {
      const apiError = {
        message: 'Server error'
      };

      const formatted = formatApiErrors(apiError);
      expect(formatted).toEqual({ _general: 'Server error' });
    });

    it('handles empty API errors', () => {
      const formatted = formatApiErrors({});
      expect(formatted).toEqual({});
    });
  });

  describe('validateField', () => {
    const schema = z.object({
      name: z.string().min(1, 'Name is required'),
      email: z.string().email('Invalid email')
    });

    it('returns null for valid field', () => {
      const fieldSchema = z.string().min(1, 'Name is required');
      const result = validateField(fieldSchema, 'John Doe', 'name');
      expect(result).toBeNull();
    });

    it('returns error message for invalid field', () => {
      const fieldSchema = z.string().min(1, 'Name is required');
      const result = validateField(fieldSchema, '', 'name');
      expect(result).toBe('Name is required');
    });

    it('handles non-Zod errors', () => {
      const invalidSchema = {
        parse: () => {
          throw new Error('Custom error');
        }
      } as any;

      const result = validateField(invalidSchema, 'value', 'field');
      expect(result).toBe('Validation error');
    });
  });

  describe('createDebouncedValidator', () => {
    it('debounces validation calls', async () => {
      const callback = vi.fn();
      const schema = z.object({
        name: z.string().min(1, 'Name is required')
      });

      const validator = createDebouncedValidator(schema, callback, 50);

      validator({ name: '' });
      validator({ name: 'John' });
      validator({ name: 'John Doe' });

      // Should not call immediately
      expect(callback).not.toHaveBeenCalled();

      // Wait for debounce
      await new Promise(resolve => setTimeout(resolve, 60));

      // Should call only once with the last value
      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith(null);
    });

    it('calls callback with errors for invalid data', async () => {
      const callback = vi.fn();
      const schema = z.object({
        name: z.string().min(1, 'Name is required')
      });

      const validator = createDebouncedValidator(schema, callback, 50);
      validator({ name: '' });

      await new Promise(resolve => setTimeout(resolve, 60));

      expect(callback).toHaveBeenCalledWith({ name: 'Name is required' });
    });
  });

  describe('commonValidators', () => {
    it('validates email correctly', () => {
      expect(() => commonValidators.email.parse('test@example.com')).not.toThrow();
      expect(() => commonValidators.email.parse('invalid-email')).toThrow();
    });

    it('validates phone correctly', () => {
      expect(() => commonValidators.phone.parse('+1234567890')).not.toThrow();
      expect(() => commonValidators.phone.parse('123-456-7890')).not.toThrow();
      expect(() => commonValidators.phone.parse('(123) 456-7890')).not.toThrow();
      expect(() => commonValidators.phone.parse(undefined)).not.toThrow();
      expect(() => commonValidators.phone.parse('abc')).toThrow();
    });

    it('validates required fields', () => {
      const validator = commonValidators.required('Custom message');
      expect(() => validator.parse('value')).not.toThrow();
      expect(() => validator.parse('')).toThrow('Custom message');
    });

    it('validates positive numbers', () => {
      expect(() => commonValidators.positiveNumber.parse(5)).not.toThrow();
      expect(() => commonValidators.positiveNumber.parse(0)).toThrow();
      expect(() => commonValidators.positiveNumber.parse(-1)).toThrow();
    });

    it('validates currency amounts', () => {
      expect(() => commonValidators.currency.parse(10.99)).not.toThrow();
      expect(() => commonValidators.currency.parse(0)).not.toThrow();
      expect(() => commonValidators.currency.parse(-1)).toThrow();
      expect(() => commonValidators.currency.parse(10.999)).toThrow();
    });
  });
});