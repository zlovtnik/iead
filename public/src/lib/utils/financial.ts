import type { Member } from '../api/members.js';
import type { Tithe, TitheCalculationResult } from '../api/tithes.js';
import type { Donation } from '../api/donations.js';

/**
 * Calculate tithe amount based on salary and percentage
 */
export function calculateTitheAmount(salary: number, percentage: number = 0.1): number {
  if (salary <= 0 || percentage <= 0) return 0;
  return Math.round((salary * percentage) * 100) / 100; // Round to 2 decimal places
}

/**
 * Calculate total giving (donations + tithes) for a member
 */
export function calculateTotalGiving(donations: Donation[], tithes: Tithe[]): {
  totalDonations: number;
  totalTithes: number;
  totalGiving: number;
  donationCount: number;
  titheCount: number;
} {
  const totalDonations = donations.reduce((sum, donation) => sum + donation.amount, 0);
  const totalTithes = tithes.reduce((sum, tithe) => sum + tithe.amount, 0);
  
  return {
    totalDonations,
    totalTithes,
    totalGiving: totalDonations + totalTithes,
    donationCount: donations.length,
    titheCount: tithes.length
  };
}

/**
 * Calculate tithe compliance rate for a member
 */
export function calculateTitheCompliance(
  member: Member,
  tithes: Tithe[],
  tithePercentage: number = 0.1
): {
  expectedAmount: number;
  actualAmount: number;
  complianceRate: number;
  monthsBehind: number;
  isCompliant: boolean;
} {
  if (!member.salary || member.salary <= 0) {
    return {
      expectedAmount: 0,
      actualAmount: 0,
      complianceRate: 0,
      monthsBehind: 0,
      isCompliant: true // No salary means no tithe obligation
    };
  }

  const currentDate = new Date();
  const currentYear = currentDate.getFullYear();
  const currentMonth = currentDate.getMonth() + 1;

  // Calculate expected tithes from start of year to current month
  const monthsInYear = currentMonth;
  const expectedMonthlyAmount = calculateTitheAmount(member.salary, tithePercentage);
  const expectedAmount = expectedMonthlyAmount * monthsInYear;

  // Calculate actual paid tithes for current year
  const currentYearTithes = tithes.filter(tithe => 
    tithe.year === currentYear && 
    tithe.month <= currentMonth &&
    tithe.is_paid
  );
  
  const actualAmount = currentYearTithes.reduce((sum, tithe) => sum + tithe.amount, 0);
  
  // Calculate compliance metrics
  const complianceRate = expectedAmount > 0 ? (actualAmount / expectedAmount) * 100 : 100;
  const monthsBehind = Math.max(0, monthsInYear - currentYearTithes.length);
  const isCompliant = complianceRate >= 90; // 90% compliance threshold

  return {
    expectedAmount,
    actualAmount,
    complianceRate: Math.round(complianceRate * 100) / 100,
    monthsBehind,
    isCompliant
  };
}

/**
 * Generate tithe calculations for multiple members
 */
export function generateTitheCalculations(
  members: Member[],
  month: number,
  year: number,
  percentage: number = 0.1,
  existingTithes: Tithe[] = []
): TitheCalculationResult[] {
  return members
    .filter(member => member.salary && member.salary > 0)
    .map(member => {
      const calculatedAmount = calculateTitheAmount(member.salary!, percentage);
      const existingTithe = existingTithes.find(
        tithe => tithe.member_id === member.id && 
                 tithe.month === month && 
                 tithe.year === year
      );

      return {
        member_id: member.id,
        member_name: member.name,
        salary: member.salary!,
        percentage,
        calculated_amount: calculatedAmount,
        existing_tithe_id: existingTithe?.id,
        existing_amount: existingTithe?.amount
      };
    });
}

/**
 * Format currency amount for display
 */
export function formatCurrency(amount: number, currency: string = 'USD', locale: string = 'en-US'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(amount);
}

/**
 * Format percentage for display
 */
export function formatPercentage(value: number, decimals: number = 1): string {
  return `${value.toFixed(decimals)}%`;
}

/**
 * Calculate giving trends over time
 */
export function calculateGivingTrends(
  donations: Donation[],
  tithes: Tithe[],
  groupBy: 'month' | 'quarter' | 'year' = 'month'
): {
  period: string;
  donations: number;
  tithes: number;
  total: number;
  donationCount: number;
  titheCount: number;
}[] {
  const combined = [
    ...donations.map(d => ({ ...d, type: 'donation' as const })),
    ...tithes.filter(t => t.is_paid).map(t => ({ 
      ...t, 
      type: 'tithe' as const,
      donation_date: t.paid_date || t.created_at 
    }))
  ];

  const grouped = new Map<string, {
    donations: number;
    tithes: number;
    donationCount: number;
    titheCount: number;
  }>();

  combined.forEach(item => {
    const date = new Date(item.donation_date || item.created_at);
    let period: string;

    switch (groupBy) {
      case 'year':
        period = date.getFullYear().toString();
        break;
      case 'quarter': {
        const quarter = Math.ceil((date.getMonth() + 1) / 3);
        period = `${date.getFullYear()}-Q${quarter}`;
        break;
      }
      case 'month':
      default:
        period = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
        break;
    }

    if (!grouped.has(period)) {
      grouped.set(period, { donations: 0, tithes: 0, donationCount: 0, titheCount: 0 });
    }

    const entry = grouped.get(period)!;
    if (item.type === 'donation') {
      entry.donations += item.amount;
      entry.donationCount++;
    } else {
      entry.tithes += item.amount;
      entry.titheCount++;
    }
  });

  return Array.from(grouped.entries())
    .map(([period, data]) => ({
      period,
      donations: data.donations,
      tithes: data.tithes,
      total: data.donations + data.tithes,
      donationCount: data.donationCount,
      titheCount: data.titheCount
    }))
    .sort((a, b) => a.period.localeCompare(b.period));
}

/**
 * Calculate member giving statistics
 */
export function calculateMemberGivingStats(
  donations: Donation[],
  tithes: Tithe[]
): {
  totalGiving: number;
  averageMonthlyGiving: number;
  largestSingleGift: number;
  mostRecentGift: Date | null;
  givingFrequency: number; // gifts per month
  titheCompliance: number;
  donationCategorySummary: Record<string, number>;
} {
  const allGifts = [
    ...donations.map(d => ({ amount: d.amount, donation_date: d.donation_date, category: d.category || 'Uncategorized' })),
    ...tithes.filter(t => t.is_paid).map(t => ({ 
      amount: t.amount, 
      donation_date: t.paid_date || t.created_at,
      category: 'Tithe'
    }))
  ];

  if (allGifts.length === 0) {
    return {
      totalGiving: 0,
      averageMonthlyGiving: 0,
      largestSingleGift: 0,
      mostRecentGift: null,
      givingFrequency: 0,
      titheCompliance: 0,
      donationCategorySummary: {}
    };
  }

  const totalGiving = allGifts.reduce((sum, gift) => sum + gift.amount, 0);
  const largestSingleGift = Math.max(...allGifts.map(gift => gift.amount));
  
  // Calculate time span for frequency calculation
  const dates = allGifts.map(gift => new Date(gift.donation_date));
  const earliestDate = new Date(Math.min(...dates.map(d => d.getTime())));
  const latestDate = new Date(Math.max(...dates.map(d => d.getTime())));
  const monthSpan = Math.max(1, 
    (latestDate.getFullYear() - earliestDate.getFullYear()) * 12 + 
    (latestDate.getMonth() - earliestDate.getMonth()) + 1
  );

  const averageMonthlyGiving = totalGiving / monthSpan;
  const givingFrequency = allGifts.length / monthSpan;

  // Calculate tithe compliance (percentage of months with tithe payments)
  const currentYear = new Date().getFullYear();
  const currentMonth = new Date().getMonth() + 1;
  const paidTithesThisYear = tithes.filter(t => 
    t.year === currentYear && 
    t.month <= currentMonth && 
    t.is_paid
  ).length;
  const titheCompliance = (paidTithesThisYear / currentMonth) * 100;

  // Categorize donations
  const donationCategorySummary: Record<string, number> = {};
  donations.forEach(donation => {
    const category = donation.category || 'Uncategorized';
    donationCategorySummary[category] = (donationCategorySummary[category] || 0) + donation.amount;
  });
  
  // Add tithes as a category
  const titheAmount = tithes.filter(t => t.is_paid).reduce((sum, t) => sum + t.amount, 0);
  if (titheAmount > 0) {
    donationCategorySummary['Tithe'] = titheAmount;
  }

  return {
    totalGiving,
    averageMonthlyGiving: Math.round(averageMonthlyGiving * 100) / 100,
    largestSingleGift,
    mostRecentGift: latestDate,
    givingFrequency: Math.round(givingFrequency * 100) / 100,
    titheCompliance: Math.round(titheCompliance * 100) / 100,
    donationCategorySummary
  };
}

/**
 * Validate tithe data consistency
 */
export function validateTitheData(tithe: Partial<Tithe>): {
  isValid: boolean;
  errors: string[];
} {
  const errors: string[] = [];

  if (tithe.amount !== undefined && tithe.amount <= 0) {
    errors.push('Tithe amount must be greater than 0');
  }

  if (tithe.month !== undefined && (tithe.month < 1 || tithe.month > 12)) {
    errors.push('Month must be between 1 and 12');
  }

  if (tithe.year !== undefined) {
    const currentYear = new Date().getFullYear();
    if (tithe.year < 1900 || tithe.year > currentYear + 1) {
      errors.push('Year must be valid and not more than 1 year in the future');
    }
  }

  if (tithe.is_paid && !tithe.paid_date) {
    errors.push('Paid date is required when tithe is marked as paid');
  }

  if (tithe.paid_date) {
    const paidDate = new Date(tithe.paid_date);
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 7); // Allow up to 7 days in future
    
    if (paidDate > futureDate) {
      errors.push('Paid date cannot be more than 7 days in the future');
    }
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Generate month names for display
 */
export function getMonthName(month: number, short: boolean = false): string {
  const months = short 
    ? ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    : ['January', 'February', 'March', 'April', 'May', 'June', 
       'July', 'August', 'September', 'October', 'November', 'December'];
  
  return months[month - 1] || 'Invalid Month';
}

/**
 * Get current financial year info
 */
export function getCurrentFinancialYear(): {
  year: number;
  month: number;
  monthsCompleted: number;
  monthsRemaining: number;
} {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  
  return {
    year,
    month,
    monthsCompleted: month,
    monthsRemaining: 12 - month
  };
}
