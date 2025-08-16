import { z } from 'zod';
import { requiredString, email, password, confirmPassword, loginPassword } from './common.js';

/**
 * Authentication-related validation schemas
 */

export const loginSchema = z.object({
  username: requiredString('Username is required'),
  // For login, only require a non-empty string; do not trim/normalize or enforce strength
  password: loginPassword,
});

export const registerSchema = z.object({
  username: requiredString('Username is required')
    .min(3, 'Username must be at least 3 characters')
    .max(50, 'Username must be 50 characters or less')
    .regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
  email: email,
  password: password,
  confirmPassword: confirmPassword(),
  member_id: z.number().int().positive().optional(),
});

export const changePasswordSchema = z.object({
  currentPassword: requiredString('Current password is required'),
  newPassword: password,
  confirmNewPassword: confirmPassword('newPassword'),
});

export const resetPasswordSchema = z.object({
  email: email,
});

export const forgotPasswordSchema = z.object({
  token: requiredString('Reset token is required'),
  password: password,
  confirmPassword: confirmPassword(),
});

export type LoginCredentials = z.infer<typeof loginSchema>;
export type RegisterData = z.infer<typeof registerSchema>;
export type ChangePasswordData = z.infer<typeof changePasswordSchema>;
export type ResetPasswordData = z.infer<typeof resetPasswordSchema>;
export type ForgotPasswordData = z.infer<typeof forgotPasswordSchema>;