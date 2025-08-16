import { z } from 'zod';

/**
 * Common validation schemas used across the application
 */

// Basic field validators
export const requiredString = (message = 'This field is required') =>
  z.string().min(1, message).trim();

export const optionalString = z.string().trim().optional();

export const email = z.string().email('Please enter a valid email address');

export const phone = z
  .string()
  .regex(/^\+?[\d\s\-\(\)]+$/, 'Please enter a valid phone number')
  .optional()
  .or(z.literal(''));

export const positiveNumber = z.number().positive('Must be a positive number');

export const nonNegativeNumber = z.number().min(0, 'Must be zero or greater');

export const currency = z
  .number()
  .min(0, 'Amount must be zero or greater')
  .multipleOf(0.01, 'Amount must have at most 2 decimal places');

export const percentage = z
  .number()
  .min(0, 'Percentage must be zero or greater')
  .max(100, 'Percentage cannot exceed 100');

// Date validators
export const dateString = z.string().refine(
  (date) => !isNaN(Date.parse(date)),
  'Please enter a valid date'
);

export const futureDate = z.string().refine(
  (date) => new Date(date) > new Date(),
  'Date must be in the future'
);

export const pastDate = z.string().refine(
  (date) => new Date(date) < new Date(),
  'Date must be in the past'
);

// Password validators
export const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/\d/, 'Password must contain at least one number');

export const confirmPassword = (passwordField = 'password') =>
  z.string().refine((value, ctx) => {
    const password = ctx.parent[passwordField];
    return value === password;
  }, 'Passwords do not match');

// URL validator
export const url = z.string().url('Please enter a valid URL').optional().or(z.literal(''));

// ID validators
export const positiveId = z.number().int().positive('Invalid ID');

export const optionalPositiveId = z.number().int().positive().optional();

// Text length validators
export const shortText = (max = 100) =>
  z.string().max(max, `Text must be ${max} characters or less`);

export const mediumText = (max = 500) =>
  z.string().max(max, `Text must be ${max} characters or less`);

export const longText = (max = 2000) =>
  z.string().max(max, `Text must be ${max} characters or less`);

// Array validators
export const nonEmptyArray = <T>(schema: z.ZodSchema<T>, message = 'At least one item is required') =>
  z.array(schema).min(1, message);

// Enum validators
export const createEnumValidator = <T extends string>(
  values: readonly T[],
  message = 'Please select a valid option'
) => z.enum(values as [T, ...T[]], { errorMap: () => ({ message }) });

// Custom refinements
export const createCustomValidator = <T>(
  validator: (value: T) => boolean,
  message: string
) => z.any().refine(validator, message);

// Conditional validators
export const conditionalRequired = (
  condition: (data: any) => boolean,
  message = 'This field is required'
) =>
  z.string().refine((value, ctx) => {
    if (condition(ctx.parent)) {
      return value && value.trim().length > 0;
    }
    return true;
  }, message);

// File validators (for future use)
export const fileSize = (maxSizeInMB: number) =>
  z.instanceof(File).refine(
    (file) => file.size <= maxSizeInMB * 1024 * 1024,
    `File size must be less than ${maxSizeInMB}MB`
  );

export const fileType = (allowedTypes: string[]) =>
  z.instanceof(File).refine(
    (file) => allowedTypes.includes(file.type),
    `File type must be one of: ${allowedTypes.join(', ')}`
  );