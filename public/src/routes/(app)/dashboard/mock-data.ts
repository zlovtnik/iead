import type { DonationSummary, AttendanceReport, MemberReport } from '$lib/api/reports.js';

// Generate donation summary that matches the DonationSummary interface
export function generateMockDonationData(): DonationSummary {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const currentMonth = new Date().getMonth();

  const donationsByMonth = months.map((_, index) => {
    // last 12 months ending in current month
    const monthIndex = ((currentMonth - 11 + index) + 12) % 12;
    const baseAmount = 4000 + Math.random() * 3000;
    let seasonalFactor = 1;
    if (monthIndex === 11) seasonalFactor = 1.8; // December
    if (monthIndex === 5) seasonalFactor = 1.3;  // June
    const amount = Math.round(baseAmount * seasonalFactor);
    const count = Math.round(10 + Math.random() * 20);
    return { month: months[monthIndex], amount, count };
  });

  const categories = ['General', 'Missions', 'Building Fund', 'Youth', 'Outreach'];
  const donationsByCategory = categories.map((category) => ({
    category,
    amount: Math.round(2000 + Math.random() * 5000),
    count: Math.round(5 + Math.random() * 15)
  }));

  // Derive some top donors
  const topDonors = Array.from({ length: 3 }).map((_, i) => ({
    memberId: i + 1,
    memberName: `Donor ${i + 1}`,
    totalAmount: Math.round(1000 + Math.random() * 4000),
    donationCount: Math.round(1 + Math.random() * 10)
  }));

  const totalDonations = donationsByMonth.reduce((sum, m) => sum + m.amount, 0);

  return {
    totalDonations,
    donationsByCategory,
    donationsByMonth,
    topDonors
  };
}

// Generate attendance report array matching AttendanceReport[]
export function generateMockAttendanceData(): AttendanceReport[] {
  const eventTitles = ['Sunday Service', 'Bible Study', 'Prayer Meeting', 'Youth Group', 'Choir Practice'];

  const items = Array.from({ length: 10 }).map((_, i) => {
    const date = new Date();
    date.setDate(date.getDate() - i * 7); // weekly spacing
    const totalAttendees = Math.round(80 + Math.random() * 40);
    const attendanceRate = Math.round(60 + Math.random() * 40); // 60-100

    const memberAttendance = Array.from({ length: 5 }).map((__, j) => ({
      memberId: j + 1,
      memberName: `Member ${j + 1}`,
      attended: Math.random() < attendanceRate / 100
    }));

    return {
      eventId: i + 1,
      eventTitle: eventTitles[i % eventTitles.length],
      eventDate: date.toISOString().split('T')[0],
      totalAttendees,
      attendanceRate,
      memberAttendance
    };
  });

  return items.reverse();
}

// Generate member report matching MemberReport
export function generateMockMemberData(): MemberReport {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const currentMonth = new Date().getMonth();

  const membersByJoinDate = months.map((_, index) => {
    const monthIndex = ((currentMonth - 11 + index) + 12) % 12;
    const count = Math.max(0, Math.round(5 + Math.random() * 15 - (11 - index) * 0.5));
    return { month: months[monthIndex], count };
  });

  const totalMembers = 120 + Math.round(Math.random() * 60);
  const newMembersThisMonth = Math.round(5 + Math.random() * 10);

  const memberEngagement = Array.from({ length: 10 }).map((_, i) => {
    const attendanceRate = Math.round(50 + Math.random() * 50);
    const donationTotal = Math.round(50 + Math.random() * 950);
    const volunteerHours = Math.round(Math.random() * 40);
    const engagementScore = Math.round(
      attendanceRate * 0.5 + (donationTotal / 1000) * 30 + (volunteerHours / 40) * 20
    );
    return {
      memberId: i + 1,
      memberName: `Member ${i + 1}`,
      attendanceRate,
      donationTotal,
      volunteerHours,
      engagementScore
    };
  });

  return {
    totalMembers,
    newMembersThisMonth,
    membersByJoinDate,
    memberEngagement
  };
}
