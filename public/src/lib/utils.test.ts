import { describe, it, expect } from 'vitest';

// Simple utility function for testing
export function formatDate(date: Date): string {
	return date.toLocaleDateString('en-US', {
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	});
}

describe('formatDate', () => {
	it('should format date correctly', () => {
		const date = new Date(2024, 0, 15); // Month is 0-indexed
		const formatted = formatDate(date);
		expect(formatted).toBe('January 15, 2024');
	});
});
