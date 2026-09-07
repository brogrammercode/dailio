import { z } from 'zod';

export const GoogleSignInSchema = z.object({
  idToken: z.string().min(1, 'Google ID token is required'),
});

export const RefreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export type GoogleSignInInput = z.infer<typeof GoogleSignInSchema>;
export type RefreshTokenInput = z.infer<typeof RefreshTokenSchema>;
