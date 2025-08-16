import type { DonationSummary, AttendanceReport, MemberReport } from '$lib/api/reports.js';

export function generateMockDonationData(): DonationSummary {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const currentMonth = new Date().getMonth();
  
  const donations = months.map((_, index) => {
    // Create a cycle with higher values in certain months over the last 12 months ending in the current month
    const monthIndex = ((currentMonth - 11 + index) + 12) % 12; // normalize to 0..11
    const baseAmount = 5000 + Math.random() * 3000;
    
    let seasonalFactor = 1;
    if (monthIndex === 11) { // December
      seasonalFactor = 2;
    } else if (monthIndex === 4) { // May
      seasonalFactor = 1.5;
    }
    
    return {
      month: months[monthIndex],
      amount: Math.round(baseAmount * seasonalFactor),
      count: Math.round(10 + Math.random() * 20)
    };
  });
      count: Math.round(10 + Math.random() * 20)
    };
  });
  
  return {
    donations: donations.slice(-12),
    totalAmount: donations.reduce((sum, item) => sum + item.amount, 0),
    totalCount: donations.reduce((sum, item) => sum + item.count, 0),
    averageAmount: Math.round(donations.reduce((sum, item) => sum + item.amount, 0) / donations.length)
  };
}

export function generateMockAttendanceData(): AttendanceReport[] {
  const events = ['Sunday Service', 'Bible Study', 'Prayer Meeting', 'Youth Group', 'Choir Practice'];
  
  return Array(10).fill(0).map((_, i) => {
    const date = new Date();
    date.setDate(date.getDate() - (i * 7)); // Weekly events
    
    return {
      event_id: i + 1,
      event_name: events[i % events.length],
      date: date.toISOString().split('T')[0],
      attendance_count: Math.round(80 + Math.random() * 40),
      capacity: 150,
      percentage: Math.round((80 + Math.random() * 40) / 150 * 100)
    };
  }).reverse();
}

export function generateMockMemberData(): MemberReport {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const currentMonth = new Date().getMonth();
  
  const growth = months.map((month, index) => {
    const monthIndex = (currentMonth - 11 + index) % 12;
    const baseValue = 100 + index * 5;
    const noise = Math.random() * 10 - 5;
    
    return {
      month: month,
      total: Math.round(baseValue + noise),
      new: Math.round(3 + Math.random() * 5),
      inactive: Math.round(Math.random() * 3)
    };
  });
  
  return {
    growth: growth.slice(-12),
    demographics: {
      ageGroups: [
        { group: '0-18', count: 35 },
        { group: '19-30', count: 40 },
        { group: '31-45', count: 50 },
        { group: '46-60', count: 30 },
        { group: '60+', count: 25 }
      ],
      genders: [
        { gender: 'Male', count: 85 },
        { gender: 'Female', count: 95 }
      ]
    }
  };
}
