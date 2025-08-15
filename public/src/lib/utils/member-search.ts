import type { Member, MemberFilters } from '../api/members.js';

/**
 * Utility functions for member search and filtering
 */

/**
 * Filter members based on search query (client-side)
 * Useful for real-time filtering of already loaded data
 */
export function filterMembersByQuery(members: Member[], query: string): Member[] {
  if (!query.trim()) return members;
  
  const searchTerm = query.toLowerCase().trim();
  
  return members.filter(member => 
    member.name.toLowerCase().includes(searchTerm) ||
    member.email.toLowerCase().includes(searchTerm) ||
    (member.phone && member.phone.toLowerCase().includes(searchTerm))
  );
}

/**
 * Apply filters to members array (client-side)
 * Useful for additional filtering of already loaded data
 */
export function applyMemberFilters(members: Member[], filters: MemberFilters): Member[] {
  return members.filter(member => {
    // Email filter
    if (filters.hasEmail !== undefined) {
      const hasEmail = Boolean(member.email);
      if (filters.hasEmail !== hasEmail) return false;
    }
    
    // Phone filter
    if (filters.hasPhone !== undefined) {
      const hasPhone = Boolean(member.phone);
      if (filters.hasPhone !== hasPhone) return false;
    }
    
    // Salary filter
    if (filters.hasSalary !== undefined) {
      const hasSalary = Boolean(member.salary);
      if (filters.hasSalary !== hasSalary) return false;
    }
    
    // Salary range filters - only apply to members with salary
    if (filters.minSalary !== undefined) {
      if (member.salary === undefined || member.salary < filters.minSalary) return false;
    }
    
    if (filters.maxSalary !== undefined) {
      if (member.salary === undefined || member.salary > filters.maxSalary) return false;
    }
    
    // Date range filters
    if (filters.createdAfter) {
      const createdDate = new Date(member.created_at);
      const afterDate = new Date(filters.createdAfter);
      if (createdDate < afterDate) return false;
    }
    
    if (filters.createdBefore) {
      const createdDate = new Date(member.created_at);
      const beforeDate = new Date(filters.createdBefore);
      if (createdDate > beforeDate) return false;
    }
    
    return true;
  });
}

/**
 * Sort members array by specified field and order
 */
export function sortMembers(
  members: Member[], 
  sortBy: 'name' | 'email' | 'created_at', 
  sortOrder: 'asc' | 'desc'
): Member[] {
  return [...members].sort((a, b) => {
    let aValue: string | number;
    let bValue: string | number;
    
    switch (sortBy) {
      case 'name':
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
        break;
      case 'email':
        aValue = a.email.toLowerCase();
        bValue = b.email.toLowerCase();
        break;
      case 'created_at':
        aValue = new Date(a.created_at).getTime();
        bValue = new Date(b.created_at).getTime();
        break;
      default:
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
    }
    
    if (aValue < bValue) {
      return sortOrder === 'asc' ? -1 : 1;
    }
    if (aValue > bValue) {
      return sortOrder === 'asc' ? 1 : -1;
    }
    return 0;
  });
}

/**
 * Highlight search terms in text
 * Useful for displaying search results with highlighted matches
 */
export function highlightSearchTerm(text: string, searchTerm: string): string {
  if (!searchTerm.trim()) return text;
  
  const regex = new RegExp(`(${escapeRegExp(searchTerm)})`, 'gi');
  return text.replace(regex, '<mark>$1</mark>');
}

/**
 * Escape special regex characters
 */
function escapeRegExp(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Get member display name with fallback
 */
export function getMemberDisplayName(member: Member): string {
  return member.name || member.email || 'Unknown Member';
}

/**
 * Format member contact information
 */
export function formatMemberContact(member: Member): string {
  const parts: string[] = [];
  
  if (member.email) {
    parts.push(member.email);
  }
  
  if (member.phone) {
    parts.push(member.phone);
  }
  
  return parts.join(' • ');
}

/**
 * Check if member matches search criteria
 */
export function memberMatchesSearch(member: Member, query: string): boolean {
  if (!query.trim()) return true;
  
  const searchTerm = query.toLowerCase().trim();
  
  return (
    member.name.toLowerCase().includes(searchTerm) ||
    member.email.toLowerCase().includes(searchTerm) ||
    (member.phone && member.phone.toLowerCase().includes(searchTerm))
  );
}

/**
 * Get member initials for avatar display
 */
export function getMemberInitials(member: Member): string {
  const name = member.name || member.email;
  if (!name) return '?';
  
  const parts = name.split(' ').filter(part => part.length > 0);
  if (parts.length === 1) {
    return parts[0].charAt(0).toUpperCase();
  }
  
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

/**
 * Format salary for display
 */
export function formatSalary(salary?: number): string {
  if (salary === undefined || salary === null) return 'Not specified';
  
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(salary);
}

/**
 * Calculate member age if birth date is available
 */
export function calculateMemberAge(birthDate?: string): number | null {
  if (!birthDate) return null;
  
  const birth = new Date(birthDate);
  const today = new Date();
  
  let age = today.getFullYear() - birth.getFullYear();
  const monthDiff = today.getMonth() - birth.getMonth();
  
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--;
  }
  
  return age;
}

/**
 * Group members by first letter of name
 */
export function groupMembersByLetter(members: Member[]): Record<string, Member[]> {
  const groups: Record<string, Member[]> = {};
  
  members.forEach(member => {
    const firstLetter = (member.name || member.email).charAt(0).toUpperCase();
    if (!groups[firstLetter]) {
      groups[firstLetter] = [];
    }
    groups[firstLetter].push(member);
  });
  
  return groups;
}

/**
 * Create search suggestions based on member data
 */
export function createSearchSuggestions(members: Member[], currentQuery: string): string[] {
  if (!currentQuery.trim()) return [];
  
  const query = currentQuery.toLowerCase();
  const suggestions = new Set<string>();
  
  members.forEach(member => {
    // Add name suggestions
    if (member.name.toLowerCase().includes(query)) {
      suggestions.add(member.name);
    }
    
    // Add email suggestions
    if (member.email.toLowerCase().includes(query)) {
      suggestions.add(member.email);
    }
    
    // Add partial name matches
    const nameParts = member.name.split(' ');
    nameParts.forEach(part => {
      if (part.toLowerCase().startsWith(query)) {
        suggestions.add(part);
      }
    });
  });
  
  return Array.from(suggestions).slice(0, 10); // Limit to 10 suggestions
}

/**
 * Debounce function for search input
 */
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout;
  
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

/**
 * Create URL search params from member search/filter state
 */
export function createMemberSearchParams(
  query: string,
  filters: MemberFilters,
  sortBy: string,
  sortOrder: string,
  page: number,
  limit: number
): URLSearchParams {
  const params = new URLSearchParams();
  
  if (query.trim()) {
    params.set('query', query.trim());
  }
  
  if (sortBy !== 'name') {
    params.set('sortBy', sortBy);
  }
  
  if (sortOrder !== 'asc') {
    params.set('sortOrder', sortOrder);
  }
  
  if (page !== 1) {
    params.set('page', page.toString());
  }
  
  if (limit !== 20) {
    params.set('limit', limit.toString());
  }
  
  // Add filters
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      params.set(key, value.toString());
    }
  });
  
  return params;
}