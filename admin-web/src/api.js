export const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

export function getToken() {
  return localStorage.getItem('admin_token') || '';
}

export function setToken(token) {
  if (!token) {
    localStorage.removeItem('admin_token');
  } else {
    localStorage.setItem('admin_token', token);
  }
}

export function getUser() {
  const raw = localStorage.getItem('admin_user');
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

export function setUser(user) {
  if (!user) {
    localStorage.removeItem('admin_user');
  } else {
    localStorage.setItem('admin_user', JSON.stringify(user));
  }
}

export function fetchMe() {
  return request('/api/me');
}

export function updateMe(payload) {
  return request('/api/me', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchNotificationPreferences() {
  return request('/api/notification-preferences');
}

export function updateNotificationPreferences(payload) {
  return request('/api/notification-preferences', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function exportMyData() {
  return request('/api/me/export');
}

export function deleteMyAccount() {
  return request('/api/me', { method: 'DELETE' });
}

async function request(path, options = {}) {
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers,
  });

  let data = null;
  let raw = '';
  try {
    raw = await res.text();
    data = raw ? JSON.parse(raw) : null;
  } catch (_) {
    data = null;
  }

  if (!res.ok) {
    const message =
      data?.message ||
      (raw && raw.length < 300 ? raw.replace(/<[^>]+>/g, '') : `Request failed (${res.status})`);
    const error = new Error(message);
    error.status = res.status;
    error.data = data;
    throw error;
  }

  return data;
}

export async function login(email, password) {
  const data = await request('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  if (data?.token) setToken(data.token);
  if (data?.user) setUser(data.user);
  return data;
}

export function fetchInstitutions({ status, search, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (search) params.append('search', search);
  params.append('page', String(page));
  params.append('per_page', String(perPage));

  return request(`/api/admin/institutions?${params.toString()}`);
}

export function createInstitution(payload) {
  return request('/api/admin/institutions', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function bulkImportInstitutions(rows) {
  return request('/api/admin/institutions/bulk-import', {
    method: 'POST',
    body: JSON.stringify({ rows }),
  });
}

export function updateInstitutionStatus(id, status) {
  return request(`/api/admin/institutions/${id}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
}

export function fetchInstitutionProfile(id) {
  return request(`/api/admin/institutions/${id}`);
}

export function updateInstitutionProfile(id, payload) {
  return request(`/api/admin/institutions/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchMyInstitutionProfile() {
  return request('/api/institutions/me');
}

export function updateMyInstitutionProfile(payload) {
  return request('/api/institutions/me', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchMyPaymentSettings() {
  return request('/api/institutions/me/payment-settings');
}

export function updateMyPaymentSettings(payload) {
  return request('/api/institutions/me/payment-settings', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchInstitutionPaymentSettings(institutionId) {
  return request(`/api/admin/institutions/${institutionId}/payment-settings`);
}

export function updateInstitutionPaymentSettings(institutionId, payload) {
  return request(`/api/admin/institutions/${institutionId}/payment-settings`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchPlatformPaymentSettings() {
  return request('/api/admin/platform-payment-settings');
}

export function updatePlatformPaymentSettings(payload) {
  return request('/api/admin/platform-payment-settings', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchNewsletterSubscribers({ status, q, page = 1, perPage = 25 } = {}) {
  const params = new URLSearchParams();
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  if (status) params.append('status', status);
  if (q) params.append('q', q);
  return request(`/api/admin/newsletter/subscribers?${params.toString()}`);
}

export function sendNewsletterLaunch(payload = {}) {
  return request('/api/admin/newsletter/send-launch', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function sendBroadcastNotification(payload = {}) {
  return request('/api/admin/notifications/broadcast', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export async function downloadNewsletterCsv() {
  const token = getToken();
  const res = await fetch(`${BASE_URL}/api/admin/newsletter/export`, {
    headers: {
      Accept: 'text/csv',
      Authorization: token ? `Bearer ${token}` : '',
    },
  });
  if (!res.ok) {
    throw new Error(`Failed to download CSV (${res.status})`);
  }
  return res.blob();
}

export function fetchUsers({ search, role, status, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (search) params.append('search', search);
  if (role) params.append('role', role);
  if (status) params.append('status', status);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));

  return request(`/api/admin/users?${params.toString()}`);
}

export function createAdmin(payload) {
  return request('/api/admin/users', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function purgeUser(userId) {
  return request(`/api/admin/users/${userId}/purge`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function updateUserAdmin(userId, payload) {
  return request(`/api/admin/users/${userId}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function suspendUser(userId) {
  return request(`/api/users/${userId}/suspend`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function reactivateUser(userId) {
  return request(`/api/users/${userId}/reactivate`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function fetchJoinRequests(institutionId, { page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/institutions/${institutionId}/join-requests?${params.toString()}`);
}

export function approveJoinRequest(institutionId, membershipId) {
  return request(`/api/institutions/${institutionId}/join-requests/${membershipId}/approve`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function rejectJoinRequest(institutionId, membershipId) {
  return request(`/api/institutions/${institutionId}/join-requests/${membershipId}/reject`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function fetchInstitutionYearGroups(institutionId) {
  return request(`/api/institutions/${institutionId}/year-groups`);
}

export function createInstitutionYearGroup(institutionId, payload) {
  return request(`/api/institutions/${institutionId}/year-groups`, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function fetchInstitutionYearGroupRequests(institutionId, { page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/institutions/${institutionId}/year-group-requests?${params.toString()}`);
}

export function approveInstitutionYearGroupRequest(institutionId, membershipId) {
  return request(`/api/institutions/${institutionId}/year-group-requests/${membershipId}/approve`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function rejectInstitutionYearGroupRequest(institutionId, membershipId) {
  return request(`/api/institutions/${institutionId}/year-group-requests/${membershipId}/reject`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function addInstitutionYearGroupMember(institutionId, groupId, userId) {
  return request(`/api/institutions/${institutionId}/year-groups/${groupId}/members`, {
    method: 'POST',
    body: JSON.stringify({ user_id: userId }),
  });
}

export function fetchEvents(institutionId, { page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/events?${params.toString()}`);
}

export function createEvent(payload) {
  return request('/api/events', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function updateEvent(eventId, payload) {
  return request(`/api/events/${eventId}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function deactivateEvent(eventId) {
  return request(`/api/events/${eventId}`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function purgeEvent(eventId) {
  return request(`/api/admin/events/${eventId}/purge`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function fetchDonations(institutionId, { page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/donation-campaigns?${params.toString()}`);
}

export function createDonationCampaign(payload) {
  return request('/api/donation-campaigns', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function updateDonationCampaign(campaignId, payload) {
  return request(`/api/donation-campaigns/${campaignId}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function deactivateDonationCampaign(campaignId) {
  return request(`/api/donation-campaigns/${campaignId}`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function purgeDonationCampaign(campaignId) {
  return request(`/api/admin/donation-campaigns/${campaignId}/purge`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function fetchInstitutionAnalytics(institutionId, { from, to } = {}) {
  const params = new URLSearchParams();
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  const suffix = params.toString();
  return request(`/api/analytics/institutions/${institutionId}${suffix ? `?${suffix}` : ''}`);
}

export function fetchPlatformAnalytics({ from, to } = {}) {
  const params = new URLSearchParams();
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  const suffix = params.toString();
  return request(`/api/analytics/platform${suffix ? `?${suffix}` : ''}`);
}

export async function downloadPlatformSchoolsPdf({ from, to, status, location } = {}) {
  const params = new URLSearchParams();
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (status) params.append('status', status);
  if (location) params.append('location', location);
  const suffix = params.toString();
  const token = getToken();
  const response = await fetch(`${BASE_URL}/api/analytics/platform/schools-pdf${suffix ? `?${suffix}` : ''}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload?.message || 'Failed to download school summary PDF');
  }
  return response.blob();
}

export function fetchUserReports({ status, query, from, to, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (query) params.append('query', query);
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/moderation/user-reports?${params.toString()}`);
}

export function resolveUserReport(reportId, status) {
  return request(`/api/moderation/user-reports/${reportId}/resolve`, {
    method: 'POST',
    body: JSON.stringify({ status }),
  });
}

export function fetchPostReports({ status, query, from, to, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (query) params.append('query', query);
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/moderation/post-reports?${params.toString()}`);
}

export function fetchReportsAnalytics({ from, to, institutionId } = {}) {
  const params = new URLSearchParams();
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (institutionId) params.append('institution_id', String(institutionId));
  const suffix = params.toString();
  return request(`/api/moderation/analytics${suffix ? `?${suffix}` : ''}`);
}

export function downloadReportsPdf({ type, status, query, from, to, institutionId } = {}) {
  const params = new URLSearchParams();
  if (type) params.append('type', type);
  if (status) params.append('status', status);
  if (query) params.append('query', query);
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (institutionId) params.append('institution_id', String(institutionId));
  const suffix = params.toString();
  const token = getToken();
  return fetch(`${BASE_URL}/api/moderation/reports-pdf${suffix ? `?${suffix}` : ''}`, {
    method: 'GET',
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      Accept: 'application/pdf',
    },
  }).then(async (res) => {
    if (!res.ok) {
      const message = `Request failed (${res.status})`;
      throw new Error(message);
    }
    return res.blob();
  });
}

export function resolvePostReport(reportId, status) {
  return request(`/api/moderation/post-reports/${reportId}/resolve`, {
    method: 'POST',
    body: JSON.stringify({ status }),
  });
}

export function fetchUserProfile(userId) {
  return request(`/api/profiles/${userId}`);
}

export function updateUserProfile(userId, payload) {
  return request(`/api/profiles/${userId}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchTransactions({ status, type, provider, currency, institutionId, search, from, to, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (type) params.append('type', type);
  if (provider) params.append('provider', provider);
  if (currency) params.append('currency', currency);
  if (institutionId) params.append('institution_id', String(institutionId));
  if (search) params.append('search', search);
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/payments/transactions?${params.toString()}`);
}

export function refundTransaction(transactionId, payload = {}) {
  return request(`/api/payments/${transactionId}/refund`, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function fetchSubscriptions({ status, interval, provider, institutionId, search, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (interval) params.append('interval', interval);
  if (provider) params.append('provider', provider);
  if (institutionId) params.append('institution_id', String(institutionId));
  if (search) params.append('search', search);
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/subscriptions?${params.toString()}`);
}

export function cancelSubscription(subscriptionId) {
  return request(`/api/admin/subscriptions/${subscriptionId}/cancel`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function fetchAds({ status, placement, search, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (placement) params.append('placement', placement);
  if (search) params.append('search', search);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/ads?${params.toString()}`);
}

export function createAd(payload) {
  return request('/api/ads', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function updateAd(adId, payload) {
  return request(`/api/ads/${adId}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function deleteAd(adId) {
  return request(`/api/ads/${adId}`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function fetchAdsAnalytics({ from, to, institutionId, status, placement } = {}) {
  const params = new URLSearchParams();
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (institutionId) params.append('institution_id', String(institutionId));
  if (status) params.append('status', status);
  if (placement) params.append('placement', placement);
  return request(`/api/ads/analytics?${params.toString()}`);
}

export function fetchAdAnalytics(adId, { from, to } = {}) {
  const params = new URLSearchParams();
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  const query = params.toString();
  return request(`/api/ads/${adId}/analytics${query ? `?${query}` : ''}`);
}

export function fetchDirectoryUsers({ q, graduationYear, industry, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  const numericYear = Number(graduationYear);
  const currentYear = new Date().getFullYear();
  const safeGraduationYear =
    Number.isInteger(numericYear) && numericYear >= 1950 && numericYear <= currentYear
      ? numericYear
      : null;
  if (q) params.append('q', q);
  if (safeGraduationYear) params.append('graduation_year', String(safeGraduationYear));
  if (industry) params.append('industry', industry);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/directory?${params.toString()}`);
}

export function fetchInstitutionsSearch({ search } = {}) {
  const params = new URLSearchParams();
  if (search) params.append('search', search);
  return request(`/api/institutions?${params.toString()}`);
}

export function fetchInstitutionPublic(id) {
  return request(`/api/institutions/public/${id}`);
}

export function fetchGlobalFeed({ page = 1, perPage = 10, sort = 'chrono' } = {}) {
  const params = new URLSearchParams();
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  params.append('sort', sort);
  return request(`/api/feed/global?${params.toString()}`);
}

export function fetchJobsAdmin({ status, q, category, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (q) params.append('q', q);
  if (category) params.append('category', category);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/jobs?${params.toString()}`);
}

export function createJob(payload) {
  return request('/api/admin/jobs', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function updateJob(jobId, payload) {
  return request(`/api/admin/jobs/${jobId}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function deleteJob(jobId) {
  return request(`/api/admin/jobs/${jobId}`, {
    method: 'DELETE',
    body: JSON.stringify({}),
  });
}

export function fetchDonationCampaignReport(campaignId) {
  return request(`/api/donation-campaigns/${campaignId}/report`);
}

export function fetchDonationCampaignDonations(campaignId, { page = 1, perPage = 50 } = {}) {
  const params = new URLSearchParams();
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/donation-campaigns/${campaignId}/donations?${params.toString()}`);
}

export function importJobsCsv(file, institutionId) {
  const form = new FormData();
  form.append('file', file);
  if (institutionId) form.append('institution_id', String(institutionId));
  const token = getToken();
  return fetch(`${BASE_URL}/api/admin/jobs/import-csv`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      Authorization: token ? `Bearer ${token}` : '',
    },
    body: form,
  }).then(async (res) => {
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      const message = data?.message || `Request failed (${res.status})`;
      const error = new Error(message);
      error.status = res.status;
      error.data = data;
      throw error;
    }
    return data;
  });
}

export function fetchJobsAnalytics({ institutionId } = {}) {
  const params = new URLSearchParams();
  if (institutionId) params.append('institution_id', String(institutionId));
  return request(`/api/admin/jobs/analytics?${params.toString()}`);
}

export function fetchAiControls() {
  return request('/api/ai/controls');
}

export function updateAiControls(payload) {
  return request('/api/ai/controls', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function fetchAiPerformance() {
  return request('/api/ai/performance');
}

export function fetchContentPerformance({ institutionId, from, to, minReactions } = {}) {
  const params = new URLSearchParams();
  if (institutionId) params.append('institution_id', String(institutionId));
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  if (minReactions) params.append('min_reactions', String(minReactions));
  const query = params.toString();
  return request(`/api/analytics/content-performance${query ? `?${query}` : ''}`);
}

export function fetchAuditLogs({ action, entityType, actorId, from, to, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (action) params.append('action', action);
  if (entityType) params.append('entity_type', entityType);
  if (actorId) params.append('actor_id', String(actorId));
  if (from) params.append('from', from);
  if (to) params.append('to', to);
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/audit-logs?${params.toString()}`);
}

export function fetchSystemSettings() {
  return request('/api/admin/settings');
}

export function fetchRoleConfig() {
  return request('/api/admin/role-config');
}

export function updateSystemSettings(settings) {
  return request('/api/admin/settings', {
    method: 'PATCH',
    body: JSON.stringify({ settings }),
  });
}

export function sendTestEmail(email) {
  return request('/api/admin/settings/test-email', {
    method: 'POST',
    body: JSON.stringify({ email }),
  });
}

export async function uploadAdminMedia(file) {
  const token = getToken();
  const form = new FormData();
  form.append('file', file);

  const res = await fetch(`${BASE_URL}/api/media/upload`, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: form,
  });

  let data = null;
  try {
    data = await res.json();
  } catch (_) {
    data = null;
  }

  if (!res.ok) {
    const message = data?.message || `Request failed (${res.status})`;
    const error = new Error(message);
    error.status = res.status;
    error.data = data;
    throw error;
  }

  return data;
}

export function fetchSupportQueue({ status, category, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (category) params.append('category', category);
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/support/queue?${params.toString()}`);
}

export function fetchNotifications({ page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/notifications?${params.toString()}`);
}

export function markNotificationRead(notificationId) {
  return request(`/api/notifications/${notificationId}/read`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function markAllNotificationsRead() {
  return request('/api/notifications/read-all', {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function registerPushToken({ token, platform = 'web', deviceId = null }) {
  return request('/api/notifications/push-token', {
    method: 'POST',
    body: JSON.stringify({
      token,
      platform,
      device_id: deviceId,
    }),
  });
}

export function unregisterPushToken(token) {
  return request('/api/notifications/push-token', {
    method: 'DELETE',
    body: JSON.stringify({ token }),
  });
}

export function generateTransactionReceipt(transactionId) {
  return request(`/api/admin/payments/transactions/${transactionId}/receipt`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function backfillReceipts(payload = {}) {
  return request('/api/admin/payments/receipts/backfill', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function resolveSupportTicket(ticketId, status, adminReply = null) {
  return request(`/api/admin/support/tickets/${ticketId}/resolve`, {
    method: 'POST',
    body: JSON.stringify({ status, admin_reply: adminReply }),
  });
}

export function replySupportTicket(ticketId, message) {
  return request(`/api/support/tickets/${ticketId}/reply`, {
    method: 'POST',
    body: JSON.stringify({ message }),
  });
}

export function createSupportTicket(payload) {
  return request('/api/support/tickets', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function fetchAnnouncements({ audience, active, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (audience) params.append('audience', audience);
  if (active !== undefined && active !== null && active !== '') params.append('active', String(active));
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/announcements?${params.toString()}`);
}

export function createAnnouncement(payload) {
  return request('/api/announcements', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

export function updateAnnouncement(id, payload) {
  return request(`/api/admin/announcements/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload),
  });
}

export function sendAnnouncementEmail(id) {
  return request(`/api/admin/announcements/${id}/send-email`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function fetchVerificationRequests({ status, institutionId, page = 1, perPage = 20 } = {}) {
  const params = new URLSearchParams();
  if (status) params.append('status', status);
  if (institutionId) params.append('institution_id', String(institutionId));
  params.append('page', String(page));
  params.append('per_page', String(perPage));
  return request(`/api/admin/verification-requests?${params.toString()}`);
}

export function verifyProfile(userId) {
  return request(`/api/profiles/${userId}/verify`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export function rejectProfile(userId, reason) {
  return request(`/api/profiles/${userId}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  });
}
