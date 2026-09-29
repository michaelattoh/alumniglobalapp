import React, { useEffect, useMemo, useRef, useState } from 'react';
import { NavLink, Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import {
  approveJoinRequest,
  addInstitutionYearGroupMember,
  approveInstitutionYearGroupRequest,
  createDonationCampaign,
  createEvent,
  createInstitutionYearGroup,
  createInstitution,
  createAd,
  deleteAd,
  fetchAds,
  fetchAdsAnalytics,
  fetchAdAnalytics,
  fetchDirectoryUsers,
  fetchInstitutionsSearch,
  fetchInstitutionPublic,
  fetchAiControls,
  fetchAiPerformance,
  fetchAuditLogs,
  fetchVerificationRequests,
  fetchDonationCampaignReport,
  fetchDonationCampaignDonations,
  downloadPlatformSchoolsPdf,
  fetchAnnouncements,
  deactivateDonationCampaign,
  deactivateEvent,
  createAnnouncement,
  fetchDonations,
  fetchEvents,
  fetchInstitutionAnalytics,
  fetchInstitutions,
  fetchInstitutionProfile,
  updateInstitutionProfile,
  fetchMyInstitutionProfile,
  updateMyInstitutionProfile,
  fetchMyPaymentSettings,
  updateMyPaymentSettings,
  fetchInstitutionPaymentSettings,
  updateInstitutionPaymentSettings,
  fetchInstitutionYearGroupRequests,
  fetchInstitutionYearGroups,
  fetchPlatformPaymentSettings,
  updatePlatformPaymentSettings,
  fetchJoinRequests,
  fetchPlatformAnalytics,
  fetchContentPerformance,
  fetchPostReports,
  fetchReportsAnalytics,
  downloadReportsPdf,
  fetchRoleConfig,
  fetchSubscriptions,
  fetchSupportQueue,
  fetchNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  registerPushToken,
  unregisterPushToken,
  generateTransactionReceipt,
  backfillReceipts,
  bulkImportInstitutions,
  fetchSystemSettings,
  fetchTransactions,
  fetchUserProfile,
  fetchUserReports,
  fetchUsers,
  fetchMe,
  updateMe,
  fetchNotificationPreferences,
  updateNotificationPreferences,
  getToken,
  getUser,
  login,
  rejectProfile,
  refundTransaction,
  cancelSubscription,
  purgeDonationCampaign,
  purgeEvent,
  purgeUser,
  reactivateUser,
  rejectJoinRequest,
  rejectInstitutionYearGroupRequest,
  resolvePostReport,
  replySupportTicket,
  resolveUserReport,
  resolveSupportTicket,
  createSupportTicket,
  setToken,
  setUser,
  suspendUser,
  updateUserAdmin,
  updateAd,
  updateAiControls,
  updateDonationCampaign,
  updateEvent,
  updateInstitutionStatus,
  updateSystemSettings,
  updateUserProfile,
  verifyProfile,
  uploadAdminMedia,
  createAdmin,
  fetchJobsAdmin,
  createJob,
  updateJob,
  deleteJob,
  importJobsCsv,
  fetchJobsAnalytics,
  updateAnnouncement,
  sendAnnouncementEmail,
  sendTestEmail,
  fetchNewsletterSubscribers,
  sendNewsletterLaunch,
  sendBroadcastNotification,
  downloadNewsletterCsv,
  exportMyData,
  deleteMyAccount,
  BASE_URL,
} from './api.js';
import {
  enableFirebaseWebPush,
  initializeFirebaseWebPush,
  disableFirebaseWebPush,
  getFirebaseWebConfig,
} from './firebaseWebPush.js';

function resolveMediaUrl(url) {
  if (!url) return '';
  if (url.startsWith('http') || url.startsWith('//')) {
    try {
      const parsed = new URL(url);
      const base = new URL(BASE_URL);
      if ((parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') && !parsed.port && base.port) {
        return `${BASE_URL}${parsed.pathname}`;
      }
    } catch (_) {}
    return url;
  }
  if (url.startsWith('/')) return `${BASE_URL}${url}`;
  return `${BASE_URL}/${url}`;
}

function currencySymbol(code) {
  const normalized = String(code || '').toUpperCase();
  if (normalized === 'GHS') return '₵';
  if (normalized === 'USD') return '$';
  if (normalized === 'GBP') return '£';
  if (normalized === 'EUR') return '€';
  return normalized || 'GHS';
}

function formatCurrency(code, amount) {
  const symbol = currencySymbol(code);
  const value = amount ?? 0;
  return `${symbol} ${value}`;
}

function parseMetadata(raw) {
  if (!raw) return {};
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw);
      return typeof parsed === 'object' && parsed ? parsed : {};
    } catch (_) {
      return {};
    }
  }
  return typeof raw === 'object' && raw ? raw : {};
}

const INSTITUTION_IMPORT_COLUMNS = [
  'name',
  'website',
  'email',
  'phone',
  'location',
  'address',
  'motto',
  'description',
];

function normalizeImportHeader(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function splitDelimitedLine(line, delimiter) {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char === delimiter && !inQuotes) {
      result.push(current.trim());
      current = '';
      continue;
    }
    current += char;
  }

  result.push(current.trim());
  return result;
}

function parseInstitutionImportSheet(text) {
  const normalized = String(text || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim();
  if (!normalized) return [];
  const lines = normalized.split('\n').filter((line) => line.trim());
  if (!lines.length) return [];
  const delimiter = lines[0].includes('\t') ? '\t' : ',';
  const headers = splitDelimitedLine(lines[0], delimiter).map(normalizeImportHeader);

  return lines.slice(1).map((line) => {
    const values = splitDelimitedLine(line, delimiter);
    return headers.reduce((acc, header, index) => {
      if (!INSTITUTION_IMPORT_COLUMNS.includes(header)) return acc;
      acc[header] = values[index] || '';
      return acc;
    }, {});
  }).filter((row) => row.name && String(row.name).trim());
}

function buildInstitutionImportTemplate() {
  const header = INSTITUTION_IMPORT_COLUMNS.join(',');
  const sample = [
    'Verix University',
    'https://verix.edu',
    'hello@verix.edu',
    '+233000000000',
    'Accra, Ghana',
    '1 Alumni Avenue',
    'Lead with service',
    'A forward-looking alumni institution profile.',
  ].map((value) => `"${String(value).replace(/"/g, '""')}"`).join(',');
  return `${header}\n${sample}`;
}

const BUILTIN_ROLE_CATALOG = {
  institution_admin: {
    label: 'Institution Admin',
    portal: 'admin',
    permissions: {
      manage_announcements: true,
      manage_events: true,
      manage_jobs: true,
      manage_donations: true,
      manage_ads: true,
      manage_support_queue: true,
      manage_moderation: true,
      view_audit_logs: true,
      view_users: true,
      view_transactions: false,
      manage_receipts: false,
      view_subscriptions: false,
    },
  },
  accountant: {
    label: 'Accountant',
    portal: 'accounting',
    permissions: {
      manage_announcements: false,
      manage_events: false,
      manage_jobs: false,
      manage_donations: false,
      manage_ads: false,
      manage_support_queue: true,
      manage_moderation: false,
      view_audit_logs: false,
      view_users: false,
      view_transactions: true,
      manage_receipts: true,
      view_subscriptions: true,
    },
  },
  support_agent: {
    label: 'Customer Support',
    portal: 'support',
    permissions: {
      manage_announcements: false,
      manage_events: false,
      manage_jobs: false,
      manage_donations: false,
      manage_ads: false,
      manage_support_queue: true,
      manage_moderation: false,
      view_audit_logs: false,
      view_users: true,
      view_transactions: false,
      manage_receipts: false,
      view_subscriptions: false,
    },
  },
};

function inferPortalFromPath(pathname = '') {
  if (pathname.startsWith('/accounting')) return 'accounting';
  if (pathname.startsWith('/customer-support')) return 'support';
  return 'admin';
}

function getRoleCatalog(config = null) {
  const next = { ...BUILTIN_ROLE_CATALOG };
  if (config && typeof config === 'object') {
    Object.entries(config).forEach(([key, value]) => {
      if (!value || typeof value !== 'object') return;
      next[key] = {
        label: value.label || key,
        portal: ['admin', 'accounting', 'support'].includes(value.portal) ? value.portal : 'admin',
        permissions: {
          ...(BUILTIN_ROLE_CATALOG[key]?.permissions || {}),
          ...(value.permissions || {}),
        },
      };
    });
  }
  return next;
}

const ACCOUNTING_NOTIFICATION_TYPES = new Set([
  'payment_pending',
  'payment_success',
  'payment_refunded',
  'subscription_payment',
]);

function isAccountingNotification(row) {
  if (!row) return false;
  const type = (row.type || '').toString().toLowerCase();
  const screen = (row?.data?.screen || '').toString().toLowerCase();
  const route = (row?.data?.route || '').toString().toLowerCase();
  return ACCOUNTING_NOTIFICATION_TYPES.has(type)
    || screen === 'payments'
    || route.startsWith('/accounting');
}

function getAccountingNotificationBucket(row) {
  const type = (row?.type || '').toString().toLowerCase();
  if (type.includes('subscription')) return 'subscriptions';
  if (type.includes('refund')) return 'receipts';
  if (type.includes('success') || type.includes('pending')) return 'payments';
  if ((row?.data?.route || '').toString().toLowerCase().includes('/billing')) return 'billing';
  return 'payments';
}

function formatPercent(value) {
  return `${Number(value || 0).toFixed(2)}%`;
}

const SUPPORT_WORKSPACE_STORAGE_KEY = 'support_workspace_state_v1';
const SUPPORT_CANNED_REPLIES = [
  'Thanks for reaching out. We are reviewing this now and will update you shortly.',
  'We need a little more information to help. Please share any screenshot, payment reference, or error message you saw.',
  'We have escalated this to the right team and will keep you posted here.',
  'This has been resolved on our side. Please refresh and try again, then let us know if the issue continues.',
];

function readSupportWorkspaceState() {
  if (typeof window === 'undefined') return {};
  try {
    const raw = window.localStorage.getItem(SUPPORT_WORKSPACE_STORAGE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function writeSupportWorkspaceState(state) {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(SUPPORT_WORKSPACE_STORAGE_KEY, JSON.stringify(state || {}));
}

function getSupportWorkspaceEntry(ticketId) {
  const state = readSupportWorkspaceState();
  return state[String(ticketId)] || {};
}

function updateSupportWorkspaceEntry(ticketId, patch) {
  const state = readSupportWorkspaceState();
  const key = String(ticketId);
  state[key] = {
    ...(state[key] || {}),
    ...patch,
    updated_at: new Date().toISOString(),
  };
  writeSupportWorkspaceState(state);
  return state[key];
}

function csvEscape(value) {
  return `"${String(value ?? '').replace(/"/g, '""')}"`;
}

function downloadCsvFile(filename, headers, rows) {
  const csv = [headers.map(csvEscape).join(','), ...rows.map((row) => row.map(csvEscape).join(','))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', filename);
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function openPortalNotification(navigate, portal, row) {
  const route = row?.data?.route;
  const screen = (row?.data?.screen || '').toString().toLowerCase();

  if (portal === 'accounting') {
    if (typeof route === 'string' && route.startsWith('/accounting')) {
      navigate(route);
      return;
    }
    if (screen === 'payments') {
      navigate('/accounting/transactions');
      return;
    }
    if (screen === 'support') {
      navigate('/accounting/billing');
      return;
    }
  }

  if (portal === 'support') {
    if (typeof route === 'string' && route.startsWith('/customer-support')) {
      navigate(route);
      return;
    }
    if (screen === 'support') {
      navigate('/customer-support/tickets');
      return;
    }
  }

  if (typeof route === 'string' && route.startsWith('/')) {
    navigate(route);
  }
}

function roleHomePath(role, roleCatalog = BUILTIN_ROLE_CATALOG) {
  if (role === 'super_admin') return '/super/institutions';
  if (role === 'institution_admin') return '/institution/dashboard';
  const portal = roleCatalog?.[role]?.portal;
  if (portal === 'accounting') return '/accounting/dashboard';
  if (portal === 'support') return '/customer-support/dashboard';
  if (portal === 'admin') return '/institution/dashboard';
  return '/';
}

function portalAllowsRole(portal, role, roleCatalog = BUILTIN_ROLE_CATALOG) {
  if (role === 'super_admin') return portal === 'admin';
  if (role === 'institution_admin') return portal === 'admin';
  const expectedPortal = roleCatalog?.[role]?.portal;
  if (!expectedPortal) return false;
  return expectedPortal === portal;
}

function toDateInput(value) {
  if (!value) return '';
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

const ADMIN_PERMISSION_DEFS = [
  { key: 'manage_announcements', label: 'Manage announcements', help: 'Create, edit, and send announcements.' },
  { key: 'manage_events', label: 'Manage events', help: 'Create, edit, and remove events.' },
  { key: 'manage_jobs', label: 'Manage jobs', help: 'Create, edit, import, and remove job listings.' },
  { key: 'manage_donations', label: 'Manage donations', help: 'Create and manage donation campaigns.' },
  { key: 'manage_ads', label: 'Manage ads', help: 'Create and manage sponsored ads.' },
  { key: 'manage_support_queue', label: 'Manage support queue', help: 'Resolve support tickets.' },
  { key: 'manage_moderation', label: 'Manage moderation', help: 'Review and resolve moderation reports.' },
  { key: 'view_audit_logs', label: 'View audit logs', help: 'Access activity and audit trail logs.' },
  { key: 'view_users', label: 'View users', help: 'Open the user directory and user profile context.' },
  { key: 'view_transactions', label: 'View transactions', help: 'Access transaction records and finance reporting.' },
  { key: 'manage_receipts', label: 'Manage receipts', help: 'Generate, backfill, and review payment receipts.' },
  { key: 'view_subscriptions', label: 'View subscriptions', help: 'Review recurring plan records and status.' },
];

const DEFAULT_ADMIN_PERMISSIONS = ADMIN_PERMISSION_DEFS.reduce((acc, item) => {
  acc[item.key] = true;
  return acc;
}, {});
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Tooltip,
  Legend,
} from 'chart.js';
import { Line, Bar } from 'react-chartjs-2';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, BarElement, Tooltip, Legend);

const STATUS_OPTIONS = [
  { value: '', label: 'All' },
  { value: 'pending', label: 'Pending' },
  { value: 'active', label: 'Active' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'suspended', label: 'Suspended' },
];

const AD_OBJECTIVES = [
  { value: 'traffic', label: 'Traffic (clicks)' },
  { value: 'awareness', label: 'Awareness (impressions)' },
  { value: 'conversion', label: 'Conversion (flat)' },
];

const AD_OBJECTIVE_PRICING = {
  traffic: 'cpc',
  awareness: 'cpm',
  conversion: 'flat',
};

function StatusPill({ status }) {
  const label = status || 'unknown';
  const color =
    status === 'active'
      ? 'pill pill--active'
      : status === 'pending'
        ? 'pill pill--pending'
        : status === 'rejected'
          ? 'pill pill--rejected'
          : status === 'suspended'
            ? 'pill pill--suspended'
            : 'pill';
  return <span className={color}>{label}</span>;
}

function PriorityPill({ priority }) {
  const value = (priority || 'normal').toString().toLowerCase();
  const supported = ['low', 'normal', 'high', 'urgent'].includes(value)
    ? value
    : 'normal';
  return (
    <span className={`notification-priority notification-priority--${supported}`}>
      {supported}
    </span>
  );
}

function ScopeNote({ label }) {
  if (!label) return null;
  return <div className="panel-note">Scoped to: {label}</div>;
}

function SoundIcon({ enabled }) {
  return (
    <svg className="sound-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M5 9v6h4l5 4V5L9 9H5z" />
      {enabled ? (
        <>
          <path d="M16 9.5c1.3 1.3 1.3 3.7 0 5" />
          <path d="M18.5 7c2.7 2.7 2.7 7.3 0 10" />
        </>
      ) : (
        <path d="M16 8l6 8M22 8l-6 8" />
      )}
    </svg>
  );
}

function BellIcon() {
  return (
    <svg className="sound-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3a4 4 0 0 0-4 4v1.2c0 .8-.2 1.7-.7 2.4L5.6 13c-.7 1-.1 2.3 1.1 2.3h10.6c1.2 0 1.8-1.3 1.1-2.3l-1.7-2.4a4.4 4.4 0 0 1-.7-2.4V7a4 4 0 0 0-4-4Z" />
      <path d="M9.8 18a2.2 2.2 0 0 0 4.4 0" />
    </svg>
  );
}

function PortalGlyph({ type }) {
  const paths = {
    dashboard: (
      <>
        <rect x="3" y="3" width="8" height="8" rx="2" />
        <rect x="13" y="3" width="8" height="5" rx="2" />
        <rect x="13" y="10" width="8" height="11" rx="2" />
        <rect x="3" y="13" width="8" height="8" rx="2" />
      </>
    ),
    transactions: (
      <>
        <path d="M4 7h16" />
        <path d="M4 12h10" />
        <path d="M4 17h7" />
        <path d="M16.5 12.5 20 16l-3.5 3.5" />
      </>
    ),
    billing: (
      <>
        <path d="M6 5h12a2 2 0 0 1 2 2v8a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4V7a2 2 0 0 1 2-2Z" />
        <path d="M8 9h8" />
        <path d="M8 13h5" />
      </>
    ),
    subscriptions: (
      <>
        <path d="M12 2v20" />
        <path d="M17 6.5c0-2-2-3.5-5-3.5S7 4.5 7 6.5 8.8 9.3 12 10s5 1.5 5 3.5-2 3.5-5 3.5-5-1.5-5-3.5" />
      </>
    ),
    failed: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M9 9l6 6M15 9l-6 6" />
      </>
    ),
    reconciliation: (
      <>
        <path d="M4 7h8" />
        <path d="M4 12h5" />
        <path d="M4 17h8" />
        <path d="M14 7h6v6" />
        <path d="M20 7l-7 7" />
      </>
    ),
    reports: (
      <>
        <path d="M7 3h7l5 5v13a1 1 0 0 1-1 1H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
        <path d="M14 3v5h5" />
        <path d="M9 13h6M9 17h6" />
      </>
    ),
    receipts: (
      <>
        <path d="M7 4h10v16l-2-1.5L13 20l-2-1.5L9 20l-2-1.5L5 20V6a2 2 0 0 1 2-2Z" />
        <path d="M9 9h6M9 13h6" />
      </>
    ),
    refresh: (
      <>
        <path d="M20 11a8 8 0 1 0 2 5.3" />
        <path d="M20 4v7h-7" />
      </>
    ),
    profile: (
      <>
        <circle cx="12" cy="8" r="3.5" />
        <path d="M5 19c1.8-3 4.1-4.5 7-4.5S17.2 16 19 19" />
      </>
    ),
    logout: (
      <>
        <path d="M9 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4" />
        <path d="M16 17l5-5-5-5" />
        <path d="M21 12H9" />
      </>
    ),
  };

  return (
    <svg className="portal-icon-svg" viewBox="0 0 24 24" aria-hidden="true">
      {paths[type] || paths.dashboard}
    </svg>
  );
}

function formatNotificationTime(value) {
  if (!value) return '';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';
  return parsed.toLocaleString([], {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function ConfirmModal({ open, title, message, confirmLabel, onCancel, onConfirm }) {
  if (!open) return null;
  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-title">{title}</div>
        <div className="modal-message">{message}</div>
        <div className="modal-actions">
          <button className="ghost" onClick={onCancel}>Cancel</button>
          <button className="primary danger" onClick={onConfirm}>{confirmLabel || 'Confirm'}</button>
        </div>
      </div>
    </div>
  );
}

function RefundModal({ open, transaction, onCancel, onConfirm }) {
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  useEffect(() => {
    if (open && transaction) {
      setAmount(String(transaction.amount ?? ''));
      setReason('');
    }
  }, [open, transaction?.id]);

  if (!open || !transaction) return null;

  const numericAmount = Number(amount);
  const invalidAmount = Number.isNaN(numericAmount) || numericAmount <= 0;

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-title">Refund transaction</div>
        <div className="modal-message">
          Refund {formatCurrency(transaction.currency, transaction.amount)} to {transaction.user?.name || 'user'}.
        </div>
        <div className="modal-form">
          <label className="label">Refund amount</label>
          <input
            className="input"
            type="number"
            min="0"
            step="0.01"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
          <label className="label">Reason (optional)</label>
          <textarea
            className="textarea"
            rows="3"
            placeholder="Reason for refund"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
        </div>
        <div className="modal-actions">
          <button className="ghost" onClick={onCancel}>Cancel</button>
          <button
            className="primary danger"
            onClick={() => onConfirm(transaction, { amount: numericAmount, reason: reason.trim() || null })}
            disabled={invalidAmount}
          >
            Refund
          </button>
        </div>
      </div>
    </div>
  );
}

function ReceiptModal({ open, url, onClose }) {
  if (!open || !url) return null;
  const isImage = /\.(png|jpe?g|gif|webp|svg)$/i.test(url);
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">Receipt</div>
        <div className="modal-message">
          {isImage ? (
            <img src={url} alt="Receipt" style={{ maxWidth: '100%', borderRadius: '12px' }} />
          ) : (
            <iframe title="Receipt" src={url} style={{ width: '100%', height: '70vh', border: 'none' }} />
          )}
        </div>
        <div className="modal-actions">
          <a className="ghost" href={url} download>Download</a>
          <button className="ghost" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

function AdAnalyticsModal({ open, ad, analytics, loading, error, range, onRangeChange, onClose }) {
  if (!open || !ad) return null;
  const series = analytics?.series || [];
  const maxValue = Math.max(
    ...series.map((item) => Math.max(item.impressions || 0, item.clicks || 0)),
    1
  );
  const totalBudget = Number(ad.budget || 0);
  const totalSpend = Number(analytics?.stats?.spend || 0);
  const totalPacing = totalBudget > 0 ? Math.min(100, Math.round((totalSpend / totalBudget) * 100)) : 0;
  const dailyBudget = ad.daily_cap_enabled ? Number(ad.daily_budget || 0) : 0;
  const dailySpend = Number(analytics?.stats?.daily_spend || 0);
  const dailyPacing = dailyBudget > 0 ? Math.min(100, Math.round((dailySpend / dailyBudget) * 100)) : 0;

  return (
    <div className="modal-backdrop">
      <div className="modal modal--wide">
        <div className="modal-title">Ad analytics · {ad.title}</div>
        <div className="modal-message">
          {ad.placement} · {ad.pricing_model?.toUpperCase()} · {ad.objective || 'traffic'}
        </div>
        <div className="modal-form">
          <div className="ads-analytics-controls">
            <input
              className="input"
              type="date"
              value={range.from}
              onChange={(e) => onRangeChange({ ...range, from: e.target.value })}
            />
            <input
              className="input"
              type="date"
              value={range.to}
              onChange={(e) => onRangeChange({ ...range, to: e.target.value })}
            />
          </div>
          {error && <div className="alert">{error}</div>}
          {loading ? (
            <div className="muted">Loading analytics...</div>
          ) : (
            <>
              <div className="metrics-grid ads-metrics">
                <div className="metric">
                  <div className="metric-title">Impressions</div>
                  <div className="metric-value">{analytics?.stats?.impressions ?? 0}</div>
                </div>
                <div className="metric">
                  <div className="metric-title">Clicks</div>
                  <div className="metric-value">{analytics?.stats?.clicks ?? 0}</div>
                  <div className="metric-subtitle">CTR {analytics?.stats?.ctr_percent ?? 0}%</div>
                </div>
                <div className="metric">
                  <div className="metric-title">Spend</div>
                  <div className="metric-value">{formatCurrency(ad.currency, analytics?.stats?.spend ?? 0)}</div>
                  <div className="metric-subtitle">
                    Budget left {formatCurrency(ad.currency, analytics?.stats?.budget_remaining ?? 0)} · {totalPacing}% used
                  </div>
                </div>
                <div className="metric">
                  <div className="metric-title">Daily cap</div>
                  <div className="metric-value">
                    {ad.daily_cap_enabled ? formatCurrency(ad.currency, ad.daily_budget || 0) : 'Disabled'}
                  </div>
                  <div className="metric-subtitle">
                    Today {formatCurrency(ad.currency, analytics?.stats?.daily_spend ?? 0)}
                    {ad.daily_cap_enabled ? ` · ${dailyPacing}% used` : ''}
                  </div>
                </div>
              </div>
              <div className="ads-chart">
                <div className="ads-chart-header">
                  <strong>Engagement trend</strong>
                  <span>{analytics?.range?.from} → {analytics?.range?.to}</span>
                </div>
                <div className="ads-chart-bars">
                  {series.map((item) => {
                    const impressionsHeight = Math.round(((item.impressions || 0) / maxValue) * 100);
                    const clicksHeight = Math.round(((item.clicks || 0) / maxValue) * 100);
                    return (
                      <div key={item.date} className="ads-chart-bar">
                        <span className="bar impressions" style={{ height: `${impressionsHeight}%` }} />
                        <span className="bar clicks" style={{ height: `${clicksHeight}%` }} />
                        <em>{item.date.slice(5)}</em>
                      </div>
                    );
                  })}
                </div>
              </div>
            </>
          )}
          <div className="modal-actions">
            <button className="ghost" onClick={onClose}>Close</button>
          </div>
        </div>
      </div>
    </div>
  );
}

function TransactionDetailModal({ open, transaction, onClose }) {
  if (!open || !transaction) return null;
  const [receiptOpen, setReceiptOpen] = useState(false);
  const normalizeMetadata = (raw) => {
    if (!raw) return null;
    let data = raw;
    if (typeof raw === 'string') {
      try {
        data = JSON.parse(raw);
      } catch (_) {
        return null;
      }
    }
    if (Array.isArray(data)) {
      const filtered = data.filter((value) => value !== null && value !== undefined && value !== '');
      return filtered.length ? filtered : null;
    }
    if (typeof data === 'object') {
      const filtered = Object.entries(data).reduce((acc, [key, value]) => {
        if (value === null || value === undefined || value === '') return acc;
        acc[key] = value;
        return acc;
      }, {});
      return Object.keys(filtered).length ? filtered : null;
    }
    return null;
  };
  const cleanedMetadata = normalizeMetadata(transaction.metadata);
  const metadata = cleanedMetadata ? JSON.stringify(cleanedMetadata, null, 2) : '';
  const feePercent = cleanedMetadata?.platform_fee_percent;
  const feeAmount = cleanedMetadata?.platform_fee_amount;
  const netAmount = cleanedMetadata?.net_amount;
  const donationTransactionId = cleanedMetadata?.donation_transaction_id;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">Transaction details</div>
        <div className="modal-message">
          <div className="detail-grid">
            <div><strong>Reference</strong><span>{transaction.reference || '-'}</span></div>
            <div><strong>Provider ref</strong><span>{transaction.provider_reference || '-'}</span></div>
            <div><strong>User</strong><span>{transaction.user?.name || '-'}</span></div>
            <div><strong>Institution</strong><span>{transaction.institution?.name || '-'}</span></div>
            <div><strong>Type</strong><span>{transaction.type}</span></div>
            <div><strong>Provider</strong><span>{transaction.provider}</span></div>
            <div><strong>Status</strong><span>{transaction.status}</span></div>
            <div><strong>Amount</strong><span>{formatCurrency(transaction.currency, transaction.amount)}</span></div>
            {feePercent !== undefined && feePercent !== null && (
              <div><strong>Platform fee (%)</strong><span>{feePercent}</span></div>
            )}
            {feeAmount !== undefined && feeAmount !== null && (
              <div><strong>Platform fee</strong><span>{formatCurrency(transaction.currency, feeAmount)}</span></div>
            )}
            {netAmount !== undefined && netAmount !== null && (
              <div><strong>Net amount</strong><span>{formatCurrency(transaction.currency, netAmount)}</span></div>
            )}
            {donationTransactionId ? (
              <div><strong>Donation txn</strong><span>{donationTransactionId}</span></div>
            ) : null}
            <div><strong>Paid at</strong><span>{transaction.paid_at ? new Date(transaction.paid_at).toLocaleString() : '-'}</span></div>
            <div><strong>Refunded at</strong><span>{transaction.refunded_at ? new Date(transaction.refunded_at).toLocaleString() : '-'}</span></div>
            <div><strong>Created</strong><span>{transaction.created_at ? new Date(transaction.created_at).toLocaleString() : '-'}</span></div>
            <div>
              <strong>Receipt</strong>
              <span>
                {transaction.receipt_url ? (
                  <button className="ghost" onClick={() => setReceiptOpen(true)}>View</button>
                ) : '-'}
              </span>
            </div>
          </div>
          {metadata && (
            <>
              <div className="modal-subtitle">Metadata</div>
              <pre className="code-block">{metadata}</pre>
            </>
          )}
        </div>
        <div className="modal-actions">
          <button className="ghost" onClick={onClose}>Close</button>
        </div>
      </div>
      <ReceiptModal open={receiptOpen} url={transaction.receipt_url} onClose={() => setReceiptOpen(false)} />
    </div>
  );
}

function GuardedModal({ open, title, message, confirmLabel, guardText, onCancel, onConfirm }) {
  const [input, setInput] = useState('');
  useEffect(() => {
    if (!open) setInput('');
  }, [open]);
  if (!open) return null;
  const allowed = input.trim().toUpperCase() === guardText;
  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-title">{title}</div>
        <div className="modal-message">{message}</div>
        <input
          className="input"
          placeholder={`Type ${guardText} to confirm`}
          value={input}
          onChange={(e) => setInput(e.target.value)}
        />
        <div className="modal-actions">
          <button className="ghost" onClick={onCancel}>Cancel</button>
          <button className="primary danger" onClick={onConfirm} disabled={!allowed}>
            {confirmLabel || 'Confirm'}
          </button>
        </div>
      </div>
    </div>
  );
}

function PostPreviewModal({ open, post, onClose }) {
  if (!open || !post) return null;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">Post preview</div>
        <div className="post-modal-header">
          <div>
            <div className="post-author">{post.user?.name || 'Unknown'}</div>
            <div className="post-date">{post.created_at ? new Date(post.created_at).toLocaleString() : ''}</div>
          </div>
          <button className="ghost" onClick={onClose}>Close</button>
        </div>
        <div className="post-content">{post.content || 'No content'}</div>
        {post.media && post.media.length > 0 && (
          <div className="post-media-grid">
            {post.media.map((m) => (
              <img key={m.id} src={m.url} alt="media" />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function UserProfilePreviewModal({ open, user, onClose }) {
  if (!open || !user) return null;
  const profile = user.profile || {};
  const skills = Array.isArray(profile.skills) ? profile.skills.join(', ') : '';
  const interests = Array.isArray(profile.interests) ? profile.interests.join(', ') : '';
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">Alumni profile</div>
        <div className="post-modal-header">
          <div>
            <div className="post-author">{user.name}</div>
            <div className="post-date">{user.email}</div>
          </div>
          <button className="ghost" onClick={onClose}>Close</button>
        </div>
        <div className="profile-grid">
          <div>
            <div className="profile-label">Institution</div>
            <div className="profile-value">{user.institution?.name || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Role</div>
            <div className="profile-value">{user.role || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Status</div>
            <div className="profile-value">{user.status || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Location</div>
            <div className="profile-value">{profile.location || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Graduation Year</div>
            <div className="profile-value">{profile.graduation_year || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Department</div>
            <div className="profile-value">{profile.department || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Program</div>
            <div className="profile-value">{profile.program || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Headline</div>
            <div className="profile-value">{profile.headline || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Company</div>
            <div className="profile-value">{profile.current_company || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Role</div>
            <div className="profile-value">{profile.current_role || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Industry</div>
            <div className="profile-value">{profile.industry || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Career focus</div>
            <div className="profile-value">{profile.career_focus || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Skills</div>
            <div className="profile-value">{skills || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Interests</div>
            <div className="profile-value">{interests || '-'}</div>
          </div>
          <div className="profile-bio">
            <div className="profile-label">Bio</div>
            <div className="profile-value">{profile.bio || '-'}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function InstitutionProfileModal({ open, institution, onClose }) {
  const navigate = useNavigate();
  if (!open || !institution) return null;
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">Institution profile</div>
        <div className="post-modal-header">
          <div>
            <div className="post-author">{institution.name || 'Institution'}</div>
            <div className="post-date">{institution.slug || ''}</div>
          </div>
          <div className="actions">
            <button className="ghost" onClick={() => navigate('/super/institutions')}>
              Open profile
            </button>
            <button className="ghost" onClick={() => navigate(`/super/analytics?institution=${institution.id}`)}>
              View analytics
            </button>
            <button className="ghost" onClick={onClose}>Close</button>
          </div>
        </div>
        <div className="profile-grid">
          <div>
            <div className="profile-label">Website</div>
            <div className="profile-value">{institution.website || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Email</div>
            <div className="profile-value">{institution.email || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Phone</div>
            <div className="profile-value">{institution.phone || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Location</div>
            <div className="profile-value">{institution.location || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Address</div>
            <div className="profile-value">{institution.address || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Motto</div>
            <div className="profile-value">{institution.motto || '-'}</div>
          </div>
          <div className="profile-bio">
            <div className="profile-label">Description</div>
            <div className="profile-value">{institution.description || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Logo</div>
            <div className="profile-value">
              {institution.logo_url ? (
                <img src={resolveMediaUrl(institution.logo_url)} alt="Logo" className="profile-media" />
              ) : '-'}
            </div>
          </div>
          <div>
            <div className="profile-label">Banner</div>
            <div className="profile-value">
              {institution.banner_url ? (
                <img src={resolveMediaUrl(institution.banner_url)} alt="Banner" className="profile-media" />
              ) : '-'}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function UserProfileModal({ open, user, profile, onClose, onSaved }) {
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    headline: profile?.headline || '',
    bio: profile?.bio || '',
    location: profile?.location || '',
    graduation_year: profile?.graduation_year || '',
    department: profile?.department || '',
    program: profile?.program || '',
    current_company: profile?.current_company || '',
    current_role: profile?.current_role || '',
    industry: profile?.industry || '',
    career_focus: profile?.career_focus || '',
    skills: profile?.skills ? profile.skills.join(', ') : '',
    interests: profile?.interests ? profile.interests.join(', ') : '',
  });

  useEffect(() => {
    if (open) {
      setForm({
        headline: profile?.headline || '',
        bio: profile?.bio || '',
        location: profile?.location || '',
        graduation_year: profile?.graduation_year || '',
        department: profile?.department || '',
        program: profile?.program || '',
        current_company: profile?.current_company || '',
        current_role: profile?.current_role || '',
        industry: profile?.industry || '',
        career_focus: profile?.career_focus || '',
        skills: profile?.skills ? profile.skills.join(', ') : '',
        interests: profile?.interests ? profile.interests.join(', ') : '',
      });
    }
  }, [open, profile]);

  if (!open || !user) return null;

  async function handleSave() {
    setSaving(true);
    try {
      await updateUserProfile(user.id, {
        headline: form.headline || null,
        bio: form.bio || null,
        location: form.location || null,
        graduation_year: form.graduation_year ? Number(form.graduation_year) : null,
        department: form.department || null,
        program: form.program || null,
        current_company: form.current_company || null,
        current_role: form.current_role || null,
        industry: form.industry || null,
        career_focus: form.career_focus || null,
        skills: form.skills
          ? form.skills.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
        interests: form.interests
          ? form.interests.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
      });
      onSaved?.();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">User profile</div>
        <div className="post-modal-header">
          <div>
            <div className="post-author">{user.name}</div>
            <div className="post-date">{user.email}</div>
          </div>
          <button className="ghost" onClick={onClose}>Close</button>
        </div>
        <div className="profile-grid">
          <div>
            <div className="profile-label">Institution</div>
            <div className="profile-value">{user.institution?.name || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Role</div>
            <div className="profile-value">{user.role || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Status</div>
            <div className="profile-value">{user.status || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Location</div>
            <input className="input" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Graduation Year</div>
            <input className="input" value={form.graduation_year} onChange={(e) => setForm({ ...form, graduation_year: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Department</div>
            <input className="input" value={form.department} onChange={(e) => setForm({ ...form, department: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Program</div>
            <input className="input" value={form.program} onChange={(e) => setForm({ ...form, program: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Headline</div>
            <input className="input" value={form.headline} onChange={(e) => setForm({ ...form, headline: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Company</div>
            <input className="input" value={form.current_company} onChange={(e) => setForm({ ...form, current_company: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Role</div>
            <input className="input" value={form.current_role} onChange={(e) => setForm({ ...form, current_role: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Industry</div>
            <input className="input" value={form.industry} onChange={(e) => setForm({ ...form, industry: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Career focus</div>
            <input className="input" value={form.career_focus} onChange={(e) => setForm({ ...form, career_focus: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Skills (comma separated)</div>
            <input className="input" value={form.skills} onChange={(e) => setForm({ ...form, skills: e.target.value })} />
          </div>
          <div>
            <div className="profile-label">Interests (comma separated)</div>
            <input className="input" value={form.interests} onChange={(e) => setForm({ ...form, interests: e.target.value })} />
          </div>
          <div className="profile-bio">
            <div className="profile-label">Bio</div>
            <textarea className="input" rows={4} value={form.bio} onChange={(e) => setForm({ ...form, bio: e.target.value })} />
          </div>
        </div>
        <div className="modal-actions">
          <button className="ghost" onClick={onClose}>Cancel</button>
          <button className="primary" onClick={handleSave} disabled={saving}>
            {saving ? 'Saving...' : 'Save changes'}
          </button>
        </div>
      </div>
    </div>
  );
}

function EditUserModal({ open, user, institutions, roleCatalog = BUILTIN_ROLE_CATALOG, onClose, onSaved }) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [form, setForm] = useState({
    role: user?.role || 'alumni',
    institution_id: user?.institution?.id || '',
    status: user?.status || 'active',
  });

  useEffect(() => {
    if (open && user) {
      setForm({
        role: user.role || 'alumni',
        institution_id: user.institution?.id || '',
        status: user.status || 'active',
      });
    }
  }, [open, user]);

  const roleOptions = useMemo(() => {
    const dynamic = Object.entries(roleCatalog || {}).map(([key, value]) => ({
      key,
      label: value?.label || key,
    }));
    return [{ key: 'alumni', label: 'Alumni' }, ...dynamic.filter((item) => item.key !== 'alumni')];
  }, [roleCatalog]);

  if (!open || !user) return null;

  async function handleSave() {
    setSaving(true);
    setError('');
    try {
      const payload = {
        role: form.role,
        status: form.status,
        institution_id: form.institution_id ? Number(form.institution_id) : null,
      };
      await updateUserAdmin(user.id, payload);
      onSaved?.(payload);
    } catch (err) {
      setError(err.message || 'Failed to update user');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-title">Edit user</div>
        <div className="modal-message">
          {user.name} • {user.email}
        </div>
        {error && <div className="alert">{error}</div>}
        <div className="modal-form">
          <select
            className="select"
            value={form.role}
            onChange={(e) => {
              const nextRole = e.target.value;
              setForm({
                ...form,
                role: nextRole,
                institution_id: ['super_admin', 'accountant', 'support_agent'].includes(nextRole) ? '' : form.institution_id,
              });
            }}
          >
            {roleOptions.map((option) => (
              <option key={option.key} value={option.key}>{option.label}</option>
            ))}
          </select>
          <select
            className="select"
            value={form.institution_id}
            onChange={(e) => setForm({ ...form, institution_id: e.target.value })}
            disabled={['super_admin', 'accountant', 'support_agent'].includes(form.role)}
          >
            <option value="">No institution</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
          <select className="select" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </select>
        </div>
        <div className="modal-actions">
          <button className="ghost" onClick={onClose}>Cancel</button>
          <button className="primary" onClick={handleSave} disabled={saving}>
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  );
}

function CreateAdminModal({ open, institutions, roleCatalog = BUILTIN_ROLE_CATALOG, onClose, onCreated }) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('super_admin');
  const [institutionId, setInstitutionId] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!open) return;
    setName('');
    setEmail('');
    setPassword('');
    setRole('super_admin');
    setInstitutionId('');
    setError('');
  }, [open]);

  const roleOptions = useMemo(() => (
    Object.entries(roleCatalog || {}).map(([key, value]) => ({
      key,
      label: value?.label || key,
    }))
  ), [roleCatalog]);

  if (!open) return null;

  async function handleSubmit() {
    if (!name.trim() || !email.trim() || !password) {
      setError('Name, email, and password are required.');
      return;
    }
    if (role === 'institution_admin' && !institutionId) {
      setError('Institution is required for institution admins.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      const res = await createAdmin({
        name: name.trim(),
        email: email.trim(),
        password,
        role,
        institution_id: role === 'institution_admin' ? Number(institutionId) : null,
      });
      onCreated?.(res?.user);
    } catch (err) {
      setError(err.message || 'Failed to create admin');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-title">Add admin</div>
        {error && <div className="alert">{error}</div>}
        <div className="card-form">
          <input className="input" placeholder="Full name" value={name} onChange={(e) => setName(e.target.value)} />
          <input className="input" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
          <input className="input" type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
          <select className="select" value={role} onChange={(e) => setRole(e.target.value)}>
            {roleOptions.map((option) => (
              <option key={option.key} value={option.key}>{option.label}</option>
            ))}
          </select>
          {role === 'institution_admin' && (
            <select className="select" value={institutionId} onChange={(e) => setInstitutionId(e.target.value)}>
              <option value="">Select institution</option>
              {institutions.map((inst) => (
                <option key={inst.id} value={inst.id}>{inst.name}</option>
              ))}
            </select>
          )}
        </div>
        <div className="modal-actions">
          <button className="ghost" onClick={onClose}>Cancel</button>
          <button className="primary" onClick={handleSubmit} disabled={saving}>
            {saving ? 'Creating...' : 'Create admin'}
          </button>
        </div>
      </div>
    </div>
  );
}

function buildSeries(base) {
  const seed = Number(base) || 1;
  return Array.from({ length: 8 }).map((_, idx) => Math.max(1, Math.round(seed * (0.6 + idx * 0.08))));
}

function LoginPanel({ onLogin, portal = 'admin' }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const portalCopy = portal === 'accounting'
    ? {
        kicker: 'Accounting Portal',
        title: 'Accounting Access',
        subtitle: 'Sign in with your accountant credentials to manage receipts, payment records, subscription activity, and billing issues.',
        note: 'Protected accounting area • Authorized finance users only',
      }
    : portal === 'support'
      ? {
          kicker: 'Customer Support Portal',
          title: 'Support Access',
          subtitle: 'Sign in with your support credentials to review users and keep support tickets moving.',
          note: 'Protected support area • Authorized support users only',
        }
      : {
          kicker: 'Dashboard Login',
          title: 'Admin Access',
          subtitle: 'Sign in with your admin credentials to manage institutions, users, and platform operations.',
          note: 'Protected admin area • Authorized users only',
        };

  async function handleSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const data = await login(email.trim(), password);
      if (!data?.token) throw new Error('Token missing');
      onLogin(data.token, data.user);
    } catch (err) {
      setError(err.message || 'Login failed');
      setToken('');
      setUser(null);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="auth-shell">
      <form className="auth-card" onSubmit={handleSubmit}>
        <div className="auth-brand-badge">Alumni Global Network</div>
        <div className="auth-kicker">{portalCopy.kicker}</div>
        <div className="auth-title">{portalCopy.title}</div>
        <p className="auth-subtitle">{portalCopy.subtitle}</p>
        {error && <div className="alert">{error}</div>}
        <label className="auth-field">
          <span>Email address</span>
          <input
            className="auth-input"
            placeholder="superadmin@alumniglobalnetwork.com"
            type="email"
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label className="auth-field">
          <span>Password</span>
          <div className="auth-input-wrap">
            <input
              className="auth-input"
              placeholder="Enter your password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <button
              type="button"
              className="auth-password-toggle"
              onClick={() => setShowPassword((prev) => !prev)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? 'Hide' : 'Show'}
            </button>
          </div>
        </label>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Signing in...' : 'Continue'}
        </button>
        <div className="auth-note">{portalCopy.note}</div>
        <div className="powered-by">Powered by Verix Teams</div>
      </form>
    </div>
  );
}

function SpecialistLayout({ user, onLogout, title, subtitle, navItems, children, portal = 'accounting' }) {
  const navigate = useNavigate();
  const location = useLocation();
  const [lastRefresh, setLastRefresh] = useState(new Date());
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [notificationItems, setNotificationItems] = useState([]);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [notificationActionBusy, setNotificationActionBusy] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [portalQueueCount, setPortalQueueCount] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshNonce, setRefreshNonce] = useState(0);
  const [avatarUrl, setAvatarUrl] = useState('');
  const notificationMenuRef = useRef(null);
  const profileMenuRef = useRef(null);
  const userInitial = (user?.name || portal || 'A').trim().charAt(0).toUpperCase();
  const accountRoute = portal === 'accounting' ? '/accounting/account' : '/customer-support/account';

  useEffect(() => {
    let cancelled = false;
    fetchMe()
      .then((payload) => {
        if (cancelled) return;
        const nextAvatar = payload?.profile?.avatar_url || payload?.user?.profile?.avatar_url || '';
        setAvatarUrl(nextAvatar);
      })
      .catch(() => {
        if (cancelled) return;
        setAvatarUrl('');
      });
    return () => {
      cancelled = true;
    };
  }, [user?.id, portal, refreshNonce]);

  useEffect(() => {
    setLastRefresh(new Date());
    setMobileNavOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (!notificationsOpen) return;
    const handlePointerDown = (event) => {
      if (notificationMenuRef.current && !notificationMenuRef.current.contains(event.target)) {
        setNotificationsOpen(false);
      }
    };
    document.addEventListener('mousedown', handlePointerDown);
    return () => document.removeEventListener('mousedown', handlePointerDown);
  }, [notificationsOpen]);

  useEffect(() => {
    if (!profileOpen) return;
    const handlePointerDown = (event) => {
      if (profileMenuRef.current && !profileMenuRef.current.contains(event.target)) {
        setProfileOpen(false);
      }
    };
    document.addEventListener('mousedown', handlePointerDown);
    return () => document.removeEventListener('mousedown', handlePointerDown);
  }, [profileOpen]);

  useEffect(() => {
    let timer = null;
    let cancelled = false;

    const loadNotifications = async () => {
      try {
        const payload = await fetchNotifications({ page: 1, perPage: 30 });
        const rows = Array.isArray(payload?.data) ? payload.data : [];
        const filtered = portal === 'accounting'
          ? rows.filter(isAccountingNotification)
          : rows.filter((row) => (row?.data?.screen || '').toString().toLowerCase() === 'support');
        if (!cancelled) {
          setNotificationItems(filtered);
          setUnreadCount(filtered.filter((row) => !row?.is_read).length);
        }
      } catch (_) {
        if (!cancelled) {
          setNotificationItems([]);
          setUnreadCount(0);
        }
      }
    };

    loadNotifications();
    timer = setInterval(loadNotifications, 20000);
    return () => {
      cancelled = true;
      if (timer) clearInterval(timer);
    };
  }, [portal, user?.id]);

  useEffect(() => {
    let timer = null;
    let cancelled = false;
    const category = portal === 'accounting' ? 'billing' : '';

    const loadQueue = async () => {
      try {
        const payload = await fetchSupportQueue({ status: 'pending', category, page: 1, perPage: 1 });
        if (!cancelled) {
          setPortalQueueCount(Number(payload?.meta?.total || 0));
        }
      } catch (_) {
        if (!cancelled) {
          setPortalQueueCount(0);
        }
      }
    };

    loadQueue();
    timer = setInterval(loadQueue, 20000);
    return () => {
      cancelled = true;
      if (timer) clearInterval(timer);
    };
  }, [portal, user?.id]);

  const handleNotificationOpen = async (row) => {
    if (!row) return;
    if (!row.is_read) {
      setNotificationActionBusy(true);
      try {
        await markNotificationRead(row.id);
        setNotificationItems((current) => current.map((item) => (
          item.id === row.id ? { ...item, is_read: true, read_at: new Date().toISOString() } : item
        )));
        setUnreadCount((count) => Math.max(0, count - 1));
      } finally {
        setNotificationActionBusy(false);
      }
    }
    openPortalNotification(navigate, portal, row);
    setNotificationsOpen(false);
  };

  const handleMarkAllRead = async () => {
    setNotificationActionBusy(true);
    try {
      await markAllNotificationsRead();
      setNotificationItems((current) => current.map((item) => ({ ...item, is_read: true, read_at: item.read_at || new Date().toISOString() })));
      setUnreadCount(0);
    } finally {
      setNotificationActionBusy(false);
    }
  };

  const handleRefresh = () => {
    setRefreshing(true);
    setNotificationsOpen(false);
    setProfileOpen(false);
    window.location.reload();
  };

  const decoratedNavItems = navItems.map((item) => {
    const isBilling = portal === 'accounting' && item.to === '/accounting/billing';
    const isSupport = portal === 'support' && item.to === '/customer-support/tickets';
    const badgeCount = isBilling || isSupport ? portalQueueCount : 0;
    return { ...item, badgeCount };
  });

  return (
    <div className={`shell shell--specialist shell--${portal}${mobileNavOpen ? ' shell--nav-open' : ''}`}>
      {mobileNavOpen && <div className="mobile-overlay" onClick={() => setMobileNavOpen(false)} />}
      <aside className="sidebar">
        <div className="specialist-sidebar-head">
          <div className="specialist-sidebar-brand">
            <span className="specialist-sidebar-mark">{portal === 'accounting' ? 'AG' : 'CS'}</span>
            <div className="specialist-sidebar-copy">
              <strong>Alumni Global Network</strong>
              <span>{portal === 'accounting' ? 'Accounting portal' : 'Customer support portal'}</span>
            </div>
          </div>
          <div className="specialist-sidebar-user">
            <span className="specialist-sidebar-user__avatar">
              {avatarUrl ? <img src={avatarUrl} alt={user?.name || 'Profile'} className="topbar-profile-pill__image" /> : userInitial}
            </span>
            <div className="specialist-sidebar-copy">
              <strong>{user?.name || 'Portal user'}</strong>
              <span>{user?.role || 'Team member'}</span>
            </div>
          </div>
        </div>
        <nav className="nav">
          {decoratedNavItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `nav-item${isActive ? ' nav-item--active' : ''}`}
              onClick={() => setMobileNavOpen(false)}
            >
              <span className="nav-item__main">
                <PortalGlyph type={item.icon} />
                <span>{item.label}</span>
              </span>
              {item.badgeCount > 0 ? <span className="nav-badge">{item.badgeCount > 99 ? '99+' : item.badgeCount}</span> : null}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="content">
        <div className="topbar">
          <div className="topbar-heading">
            <button
              className="ghost mobile-nav-toggle"
              onClick={() => setMobileNavOpen((prev) => !prev)}
              aria-label="Toggle navigation"
              type="button"
            >
              <span className="hamburger">
                <span />
                <span />
                <span />
              </span>
            </button>
            <div className="topbar-title">{title}</div>
            <div className="topbar-subtitle">{subtitle}</div>
          </div>
          <div className="topbar-actions">
            <div className="topbar-chip">
              Live · {lastRefresh.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </div>
            <button
              className="ghost topbar-icon-button"
              type="button"
              onClick={handleRefresh}
              disabled={refreshing}
              title={refreshing ? 'Refreshing portal' : 'Refresh portal'}
            >
              <PortalGlyph type="refresh" />
            </button>
            <div className="notification-menu" ref={notificationMenuRef}>
              <button
                className={`ghost notification-toggle ${notificationsOpen ? 'notification-toggle--active' : ''}`}
                type="button"
                onClick={() => setNotificationsOpen((prev) => !prev)}
                title="Notifications"
              >
                <BellIcon />
                {unreadCount > 0 && <span className="notification-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>}
              </button>
              {notificationsOpen && (
                <div className="notification-panel">
                  <div className="notification-panel__header">
                    <div>
                      <strong>{portal === 'accounting' ? 'Payment notifications' : 'Support notifications'}</strong>
                      <small>{unreadCount > 0 ? `${unreadCount} unread` : 'All caught up'}</small>
                    </div>
                    <button className="ghost" type="button" onClick={handleMarkAllRead} disabled={notificationActionBusy || unreadCount === 0}>
                      Mark all read
                    </button>
                  </div>
                  <div className="notification-panel__list">
                    {notificationItems.length === 0 ? (
                      <div className="notification-empty">
                        {portal === 'accounting' ? 'No payment notifications yet.' : 'No support notifications yet.'}
                      </div>
                    ) : (
                      notificationItems.map((row) => (
                        <button
                          key={row.id}
                          type="button"
                          className={`notification-row ${row.is_read ? '' : 'notification-row--unread'}`}
                          onClick={() => handleNotificationOpen(row)}
                          disabled={notificationActionBusy}
                        >
                          <div className="notification-row__meta">
                            <div className="notification-row__title-wrap">
                              <strong>{row.title}</strong>
                            </div>
                            <span>{formatNotificationTime(row.sent_at || row.created_at)}</span>
                          </div>
                          {row.body ? <div className="notification-row__body">{row.body}</div> : null}
                        </button>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>
            <div className="topbar-chip">
              {portal === 'accounting' ? `${portalQueueCount} billing issue${portalQueueCount === 1 ? '' : 's'}` : `${portalQueueCount} tickets waiting`}
            </div>
            <div className="profile-menu" ref={profileMenuRef}>
              <button
                className="ghost topbar-profile-pill"
                type="button"
                title={user?.name || 'Profile'}
                onClick={() => setProfileOpen((prev) => !prev)}
              >
                <span className="topbar-profile-pill__avatar">
                  {avatarUrl ? <img src={avatarUrl} alt={user?.name || 'Profile'} className="topbar-profile-pill__image" /> : userInitial}
                </span>
                <span className="topbar-profile-pill__copy">
                  <strong>{user?.name || 'Portal user'}</strong>
                  <small>{portal === 'accounting' ? 'Accounts' : 'Support'}</small>
                </span>
              </button>
              {profileOpen && (
                <div className="profile-panel">
                  <div className="profile-panel__header">
                    <span className="profile-panel__avatar">
                      {avatarUrl ? <img src={avatarUrl} alt={user?.name || 'Profile'} className="topbar-profile-pill__image" /> : userInitial}
                    </span>
                    <div className="profile-panel__copy">
                      <strong>{user?.name || 'Portal user'}</strong>
                      <span>{user?.email || 'No email available'}</span>
                    </div>
                  </div>
                  <div className="profile-panel__grid">
                    <div>
                      <strong>Role</strong>
                      <span>{user?.role || 'team_member'}</span>
                    </div>
                    <div>
                      <strong>Portal</strong>
                      <span>{portal === 'accounting' ? 'Accounting' : 'Customer Support'}</span>
                    </div>
                  </div>
                  <div className="profile-panel__actions">
                    <button className="ghost" type="button" onClick={() => { navigate(accountRoute); setProfileOpen(false); }}>
                      Open account
                    </button>
                    <button className="ghost" type="button" onClick={handleRefresh} disabled={refreshing}>
                      {refreshing ? 'Refreshing...' : 'Refresh data'}
                    </button>
                    <button className="ghost" type="button" onClick={onLogout}>
                      Sign out
                    </button>
                  </div>
                </div>
              )}
            </div>
            <button className="ghost topbar-icon-button topbar-icon-button--danger" type="button" onClick={onLogout} title="Log out">
              <PortalGlyph type="logout" />
            </button>
          </div>
        </div>
        <div key={refreshNonce}>
          {children}
        </div>
        <footer className="powered-by powered-by--content">Powered by Verix Teams</footer>
      </main>
    </div>
  );
}

function AccountingOverviewView() {
  const navigate = useNavigate();
  const [summary, setSummary] = useState({ loading: true, error: '', totals: null, subscriptions: null, billing: null });

  useEffect(() => {
    let cancelled = false;
    Promise.all([
      fetchTransactions({ page: 1, perPage: 25 }),
      fetchSubscriptions({ page: 1, perPage: 25 }),
      fetchSupportQueue({ status: 'pending', category: 'billing', page: 1, perPage: 25 }),
    ])
      .then(([transactions, subscriptions, billingQueue]) => {
        if (cancelled) return;
        const rows = transactions?.data || [];
        const total = rows.reduce((sum, row) => sum + Number(row?.amount || 0), 0);
        const feeTotal = rows.reduce((sum, row) => {
          const meta = row?.metadata && typeof row.metadata === 'object' ? row.metadata : {};
          return sum + Number(meta?.platform_fee_amount || 0);
        }, 0);
        const receiptsReady = rows.filter((row) => Boolean(row?.receipt_url)).length;
        const successful = rows.filter((row) => row?.status === 'success').length;
        const pending = rows.filter((row) => row?.status === 'pending').length;
        const failed = rows.filter((row) => row?.status === 'failed').length;
        const settledNet = rows
          .filter((row) => ['success', 'refunded'].includes((row?.status || '').toString()))
          .reduce((sum, row) => sum + Number(parseMetadata(row.metadata)?.net_amount ?? (Number(row.amount ?? 0) - Number(parseMetadata(row.metadata)?.platform_fee_amount ?? 0))), 0);
        const needsReceipt = rows.filter((row) => ['success', 'refunded'].includes((row?.status || '').toString()) && !row?.receipt_url).length;
        const effectiveFeeRate = total > 0 ? (feeTotal / total) * 100 : 0;
        const subRows = subscriptions?.data || [];
        const activeSubs = subRows.filter((row) => row?.status === 'active').length;
        const billingRows = billingQueue?.data || [];
        setSummary({
          loading: false,
          error: '',
          totals: { total, feeTotal, effectiveFeeRate, count: rows.length, receiptsReady, successful, pending, failed, settledNet, needsReceipt },
          subscriptions: { total: subRows.length, active: activeSubs },
          billing: {
            total: billingQueue?.meta?.total || billingRows.length,
            urgent: billingRows.filter((row) => (row?.payload?.priority || '').toString().toLowerCase() === 'urgent').length,
          },
        });
      })
      .catch((err) => {
        if (cancelled) return;
        setSummary({ loading: false, error: err.message || 'Failed to load accounting dashboard', totals: null, subscriptions: null, billing: null });
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Accounting dashboard</h2>
          <p>Run receipts, monitor payment health, and stay close to billing issues from one finance-first command centre.</p>
        </div>
      </div>
      {summary.error && <div className="alert">{summary.error}</div>}
      <div className="detail-grid accounting-overview-grid">
        <div className="metric">
          <span className="metric-label">Transactions</span>
          <strong>{summary.loading ? '—' : summary.totals?.count ?? 0}</strong>
          <small>Recent payment records</small>
        </div>
        <div className="metric">
          <span className="metric-label">Receipts ready</span>
          <strong>{summary.loading ? '—' : summary.totals?.receiptsReady ?? 0}</strong>
          <small>Ready for alumni access</small>
        </div>
        <div className="metric">
          <span className="metric-label">Pending payments</span>
          <strong>{summary.loading ? '—' : summary.totals?.pending ?? 0}</strong>
          <small>Do not generate receipts for these yet</small>
        </div>
        <div className="metric">
          <span className="metric-label">Platform fee rate</span>
          <strong>{summary.loading ? '—' : formatPercent(summary.totals?.effectiveFeeRate ?? 0)}</strong>
          <small>Effective fee against tracked volume</small>
        </div>
        <div className="metric">
          <span className="metric-label">Successful</span>
          <strong>{summary.loading ? '—' : summary.totals?.successful ?? 0}</strong>
          <small>Successful payment entries</small>
        </div>
        <div className="metric">
          <span className="metric-label">Active subscriptions</span>
          <strong>{summary.loading ? '—' : summary.subscriptions?.active ?? 0}</strong>
          <small>Current recurring plans</small>
        </div>
        <div className="metric">
          <span className="metric-label">Failed payments</span>
          <strong>{summary.loading ? '—' : summary.totals?.failed ?? 0}</strong>
          <small>Needs finance follow-up</small>
        </div>
        <div className="metric">
          <span className="metric-label">Billing tickets</span>
          <strong>{summary.loading ? '—' : summary.billing?.total ?? 0}</strong>
          <small>Open finance-related support issues</small>
        </div>
        <div className="metric">
          <span className="metric-label">Urgent billing</span>
          <strong>{summary.loading ? '—' : summary.billing?.urgent ?? 0}</strong>
          <small>Cases to triage first</small>
        </div>
      </div>
      <div className="stack">
      <div className="card accounting-callout-card">
        <div className="card-title-row">
          <div>
            <h3>Finance workflow</h3>
            <p>Keep receipts moving, stay strict on pending rows, and handle billing-related tickets without leaving the portal.</p>
          </div>
        </div>
        <div className="detail-grid">
          <div><strong>Total volume</strong><span>{summary.loading ? '—' : formatCurrency('GHS', summary.totals?.total ?? 0)}</span></div>
          <div><strong>Platform fees</strong><span>{summary.loading ? '—' : formatCurrency('GHS', summary.totals?.feeTotal ?? 0)}</span></div>
          <div><strong>Settlement base</strong><span>{summary.loading ? '—' : formatCurrency('GHS', summary.totals?.settledNet ?? 0)}</span></div>
          <div><strong>Subscriptions tracked</strong><span>{summary.loading ? '—' : summary.subscriptions?.total ?? 0}</span></div>
          <div><strong>Receipts waiting</strong><span>{summary.loading ? '—' : summary.totals?.needsReceipt ?? 0}</span></div>
          <div><strong>Recommended review</strong><span>Pending rows + urgent billing tickets</span></div>
        </div>
      </div>
      <div className="card accounting-ops-card">
        <div className="card-title-row">
          <div>
            <h3>Operations lanes</h3>
            <p>The sidebar is now split into the work an accountant actually touches every day.</p>
          </div>
        </div>
        <div className="detail-grid">
          <div><strong>Transactions</strong><span>Review pending, success, refunded, and provider references.</span></div>
          <div><strong>Failed bucket</strong><span>Catch rows that need retry, outreach, or provider investigation.</span></div>
          <div><strong>Reconciliation</strong><span>Watch fee percentages, provider splits, and settlement-ready net.</span></div>
          <div><strong>Reports</strong><span>Download finance snapshots without leaving the portal.</span></div>
          <div><strong>Receipt log</strong><span>See who already has a receipt and what still needs one.</span></div>
          <div><strong>Billing tickets</strong><span>Resolve support issues tagged as billing only.</span></div>
          <div><strong>Subscriptions</strong><span>Watch active recurring plans and cancellations.</span></div>
          <div><strong>Receipts</strong><span>Generate only after payment is successful or refunded.</span></div>
        </div>
        <div className="pill-group">
          <button className="ghost" type="button" onClick={() => navigate('/accounting/failed-payments')}>Open failed bucket</button>
          <button className="ghost" type="button" onClick={() => navigate('/accounting/reconciliation')}>Open reconciliation</button>
          <button className="ghost" type="button" onClick={() => navigate('/accounting/reports')}>Open reports</button>
          <button className="ghost" type="button" onClick={() => navigate('/accounting/receipts')}>Open receipt log</button>
        </div>
      </div>
      </div>
    </div>
  );
}

function AccountingFailedPaymentsView() {
  return (
    <TransactionsView
      portalMode="accounting"
      initialFilters={{ status: 'failed' }}
      headingOverride="Failed payments"
      subtitleOverride="A clean bucket for failed rows that need retry checks, payer follow-up, or provider investigation."
    />
  );
}

function AccountingReconciliationView() {
  const [state, setState] = useState({ loading: true, error: '', rows: [] });

  useEffect(() => {
    let cancelled = false;
    fetchTransactions({ page: 1, perPage: 100 })
      .then((payload) => {
        if (cancelled) return;
        setState({ loading: false, error: '', rows: payload?.data || [] });
      })
      .catch((err) => {
        if (cancelled) return;
        setState({ loading: false, error: err.message || 'Failed to load reconciliation view', rows: [] });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const summary = useMemo(() => {
    const map = new Map();
    state.rows.forEach((row) => {
      const provider = (row?.provider || 'unknown').toString().toLowerCase();
      const meta = typeof row?.metadata === 'object' && row.metadata ? row.metadata : {};
      const amount = Number(row?.amount || 0);
      const fee = Number(meta?.platform_fee_amount || 0);
      const net = Number(meta?.net_amount ?? (amount - fee));
      const current = map.get(provider) || { provider, gross: 0, fee: 0, net: 0, successful: 0, pending: 0, failed: 0 };
      current.gross += amount;
      current.fee += fee;
      current.net += ['success', 'refunded'].includes((row?.status || '').toString()) ? net : 0;
      current.successful += row?.status === 'success' ? 1 : 0;
      current.pending += row?.status === 'pending' ? 1 : 0;
      current.failed += row?.status === 'failed' ? 1 : 0;
      map.set(provider, current);
    });
    return [...map.values()];
  }, [state.rows]);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Reconciliation</h2>
          <p>Compare provider volume, platform fees, and settlement-ready net before finance closes the loop.</p>
        </div>
      </div>
      {state.error && <div className="alert">{state.error}</div>}
      <div className="table table--wide">
        <div className="table-row table-row--head">
          <div>Provider</div>
          <div>Gross volume</div>
          <div>Platform fees</div>
          <div>Settlement net</div>
          <div>Successful</div>
          <div>Pending</div>
          <div>Failed</div>
          <div>Fee rate</div>
        </div>
        {state.loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : summary.length === 0 ? (
          <div className="table-row"><div>No transactions available for reconciliation.</div></div>
        ) : (
          summary.map((row) => (
            <div className="table-row" key={row.provider}>
              <div>{row.provider}</div>
              <div>{formatCurrency('GHS', row.gross.toFixed(2))}</div>
              <div>{formatCurrency('GHS', row.fee.toFixed(2))}</div>
              <div>{formatCurrency('GHS', row.net.toFixed(2))}</div>
              <div>{row.successful}</div>
              <div>{row.pending}</div>
              <div>{row.failed}</div>
              <div>{row.gross > 0 ? formatPercent((row.fee / row.gross) * 100) : '0.00%'}</div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function AccountingReportsView() {
  const [state, setState] = useState({ loading: true, error: '', transactions: [], subscriptions: [], billing: [] });

  useEffect(() => {
    let cancelled = false;
    Promise.all([
      fetchTransactions({ page: 1, perPage: 100 }),
      fetchSubscriptions({ page: 1, perPage: 100 }),
      fetchSupportQueue({ status: 'pending', category: 'billing', page: 1, perPage: 100 }),
    ])
      .then(([transactions, subscriptions, billing]) => {
        if (cancelled) return;
        setState({
          loading: false,
          error: '',
          transactions: transactions?.data || [],
          subscriptions: subscriptions?.data || [],
          billing: billing?.data || [],
        });
      })
      .catch((err) => {
        if (cancelled) return;
        setState({ loading: false, error: err.message || 'Failed to load finance reports', transactions: [], subscriptions: [], billing: [] });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const exportTransactions = () => {
    downloadCsvFile('accounting-transactions.csv', ['Reference', 'User', 'Provider', 'Type', 'Amount', 'Status', 'Receipt'], state.transactions.map((row) => [
      row.reference || '',
      row.user?.name || '',
      row.provider || '',
      row.type || '',
      row.amount || 0,
      row.status || '',
      row.receipt_url ? 'Ready' : 'Missing',
    ]));
  };

  const exportFees = () => {
    downloadCsvFile('platform-fees.csv', ['Reference', 'Amount', 'Platform Fee', 'Fee Percent', 'Net', 'Status'], state.transactions.map((row) => {
      const meta = typeof row?.metadata === 'object' && row.metadata ? row.metadata : {};
      return [
        row.reference || '',
        row.amount || 0,
        meta?.platform_fee_amount || 0,
        meta?.platform_fee_percent || 0,
        meta?.net_amount ?? (Number(row.amount || 0) - Number(meta?.platform_fee_amount || 0)),
        row.status || '',
      ];
    }));
  };

  const exportBilling = () => {
    downloadCsvFile('billing-tickets.csv', ['Reference', 'User', 'Subject', 'Priority', 'Status'], state.billing.map((row) => [
      row?.payload?.reference || '',
      row?.payload?.user?.name || '',
      row?.payload?.subject || '',
      row?.payload?.priority || '',
      row?.payload?.status || '',
    ]));
  };

  const exportSubscriptions = () => {
    downloadCsvFile('subscriptions.csv', ['User', 'Plan', 'Interval', 'Amount', 'Status'], state.subscriptions.map((row) => [
      row.user?.name || '',
      row.plan_name || '',
      row.interval || '',
      row.amount || 0,
      row.status || '',
    ]));
  };

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Finance reports</h2>
          <p>Download quick accounting snapshots for reconciliation, fee review, receipts, and billing work.</p>
        </div>
      </div>
      {state.error && <div className="alert">{state.error}</div>}
      <div className="detail-grid">
        <div><strong>Transactions CSV</strong><span>Raw payment records for finance review.</span><button className="ghost" type="button" onClick={exportTransactions} disabled={state.loading}>Download</button></div>
        <div><strong>Fee report</strong><span>Platform fee amounts and effective fee rates.</span><button className="ghost" type="button" onClick={exportFees} disabled={state.loading}>Download</button></div>
        <div><strong>Billing tickets</strong><span>Open billing support issues for the accounting lane.</span><button className="ghost" type="button" onClick={exportBilling} disabled={state.loading}>Download</button></div>
        <div><strong>Subscriptions</strong><span>Recurring revenue and cancellation snapshot.</span><button className="ghost" type="button" onClick={exportSubscriptions} disabled={state.loading}>Download</button></div>
      </div>
    </div>
  );
}

function ReceiptActivityView() {
  const [state, setState] = useState({ loading: true, error: '', rows: [] });

  useEffect(() => {
    let cancelled = false;
    fetchTransactions({ page: 1, perPage: 100 })
      .then((payload) => {
        if (cancelled) return;
        setState({ loading: false, error: '', rows: payload?.data || [] });
      })
      .catch((err) => {
        if (cancelled) return;
        setState({ loading: false, error: err.message || 'Failed to load receipt activity', rows: [] });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const receiptRows = useMemo(() => state.rows.filter((row) => ['success', 'refunded', 'pending', 'failed'].includes((row?.status || '').toString())), [state.rows]);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Receipt activity</h2>
          <p>Track what already has a receipt, what is waiting, and which pending rows should stay blocked.</p>
        </div>
      </div>
      {state.error && <div className="alert">{state.error}</div>}
      <div className="table table--wide">
        <div className="table-row table-row--head">
          <div>Reference</div>
          <div>User</div>
          <div>Status</div>
          <div>Receipt state</div>
          <div>Provider</div>
          <div>Amount</div>
        </div>
        {state.loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : receiptRows.length === 0 ? (
          <div className="table-row"><div>No receipt activity found.</div></div>
        ) : (
          receiptRows.map((row) => (
            <div className="table-row" key={row.id}>
              <div>{row.reference || '-'}</div>
              <div>{row.user?.name || '-'}</div>
              <div><StatusPill status={row.status} /></div>
              <div>{row.receipt_url ? 'Receipt ready' : ['success', 'refunded'].includes((row?.status || '').toString()) ? 'Waiting for receipt' : 'Blocked until payment clears'}</div>
              <div>{row.provider || '-'}</div>
              <div>{formatCurrency(row.currency, row.amount)}</div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function SpecialistAccountView({ user, portal = 'accounting', onLogout }) {
  const fileInputRef = useRef(null);
  const [avatarUrl, setAvatarUrl] = useState('');
  const [accountIdentity, setAccountIdentity] = useState(user);
  const [savingAvatar, setSavingAvatar] = useState(false);
  const [preferenceStatus, setPreferenceStatus] = useState('');
  const [preferences, setPreferences] = useState(() => {
    return {
      browserAlerts: true,
      emailDigest: portal === 'accounting',
      urgentOnly: false,
      payments: true,
      billing: true,
      subscriptions: portal === 'accounting',
      receipts: portal === 'accounting',
    };
  });
  const [activityFilter, setActivityFilter] = useState('all');
  const [activity, setActivity] = useState({ loading: true, error: '', rows: [] });

  useEffect(() => {
    let cancelled = false;
    Promise.all([fetchMe(), fetchNotificationPreferences()])
      .then(([mePayload, prefPayload]) => {
        if (cancelled) return;
        const currentUser = mePayload?.user || user;
        const profile = mePayload?.profile || currentUser?.profile || {};
        const pref = prefPayload?.data || {};
        setAccountIdentity(currentUser);
        setAvatarUrl(profile?.avatar_url || '');
        setPreferences((prev) => ({
          ...prev,
          browserAlerts: pref.push_enabled ?? prev.browserAlerts,
          emailDigest: pref.email_enabled ?? prev.emailDigest,
          payments: pref.in_app_enabled ?? prev.payments,
          billing: pref.connections_enabled ?? prev.billing,
          subscriptions: pref.events_enabled ?? prev.subscriptions,
          receipts: pref.messages_enabled ?? prev.receipts,
        }));
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [portal, user]);

  useEffect(() => {
    let cancelled = false;
    fetchNotifications({ page: 1, perPage: 20 })
      .then((payload) => {
        if (cancelled) return;
        const rows = Array.isArray(payload?.data) ? payload.data : [];
        const filtered = portal === 'accounting'
          ? rows.filter(isAccountingNotification)
          : rows.filter((row) => (row?.data?.screen || '').toString().toLowerCase() === 'support');
        setActivity({ loading: false, error: '', rows: filtered.slice(0, 8) });
      })
      .catch((err) => {
        if (cancelled) return;
        setActivity({ loading: false, error: err.message || 'Failed to load activity', rows: [] });
      });
    return () => {
      cancelled = true;
    };
  }, [portal]);

  const filteredRows = useMemo(() => {
    if (activityFilter === 'all') return activity.rows;
    if (portal !== 'accounting') return activity.rows;
    return activity.rows.filter((row) => getAccountingNotificationBucket(row) === activityFilter);
  }, [activity.rows, activityFilter, portal]);

  const handleAvatarPick = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    setSavingAvatar(true);
    try {
      const upload = await uploadAdminMedia(file);
      const mediaUrl = upload?.url || upload?.data?.url || '';
      if (!mediaUrl) {
        throw new Error('Avatar upload failed');
      }
      const updated = await updateMe({ avatar_url: mediaUrl });
      const profile = updated?.profile || updated?.user?.profile || {};
      const nextAvatar = profile?.avatar_url || mediaUrl;
      setAvatarUrl(nextAvatar);
      setAccountIdentity(updated?.user || accountIdentity);
    } catch (_) {
      setPreferenceStatus('Avatar upload failed.');
    } finally {
      setSavingAvatar(false);
    }
    event.target.value = '';
  };

  const savePreferences = async (nextPreferences) => {
    setPreferences(nextPreferences);
    setPreferenceStatus('Saving preferences...');
    try {
      await updateNotificationPreferences({
        push_enabled: nextPreferences.browserAlerts,
        email_enabled: nextPreferences.emailDigest,
        in_app_enabled: nextPreferences.payments,
        connections_enabled: nextPreferences.billing,
        events_enabled: nextPreferences.subscriptions,
        messages_enabled: nextPreferences.receipts,
      });
      setPreferenceStatus('Preferences saved.');
    } catch (err) {
      setPreferenceStatus(err.message || 'Failed to save preferences.');
    }
  };

  return (
    <div className="stack">
      <div className="panel">
        <div className="panel-header">
          <div>
            <h2>My account</h2>
            <p>Keep your portal identity, notification behaviour, and recent activity in one place.</p>
          </div>
        </div>
        <div className="account-profile-hero">
          <div className="account-profile-hero__avatar">
            {avatarUrl ? <img src={avatarUrl} alt={accountIdentity?.name || 'Profile'} className="account-profile-hero__image" /> : (accountIdentity?.name || portal || 'A').trim().charAt(0).toUpperCase()}
          </div>
          <div className="account-profile-hero__copy">
            <strong>{accountIdentity?.name || 'Portal user'}</strong>
            <span>{accountIdentity?.email || 'No email available'}</span>
            <small>{portal === 'accounting' ? 'Accounting workspace' : 'Support workspace'}</small>
          </div>
          <div className="account-profile-hero__actions">
            <input ref={fileInputRef} type="file" accept="image/*" hidden onChange={handleAvatarPick} />
            <button className="ghost" type="button" onClick={() => fileInputRef.current?.click()} disabled={savingAvatar}>
              {savingAvatar ? 'Uploading...' : avatarUrl ? 'Change avatar' : 'Add avatar'}
            </button>
          </div>
        </div>
        <div className="profile-grid">
          <div>
            <div className="profile-label">Name</div>
            <div className="profile-value">{accountIdentity?.name || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Email</div>
            <div className="profile-value">{accountIdentity?.email || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Role</div>
            <div className="profile-value">{accountIdentity?.role || '-'}</div>
          </div>
          <div>
            <div className="profile-label">Portal</div>
            <div className="profile-value">{portal === 'accounting' ? 'Accounting' : 'Customer Support'}</div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="card-header">
          <div>
            <h3>Notification preferences</h3>
            <p>Keep accountants focused on payment events and billing issues without extra noise.</p>
          </div>
        </div>
        <div className="detail-grid">
          <div>
            <strong>Browser alerts</strong>
            <label><input type="checkbox" checked={preferences.browserAlerts} onChange={(e) => savePreferences({ ...preferences, browserAlerts: e.target.checked })} /> Enable in-browser alerts</label>
          </div>
          <div>
            <strong>Email digest</strong>
            <label><input type="checkbox" checked={preferences.emailDigest} onChange={(e) => savePreferences({ ...preferences, emailDigest: e.target.checked })} /> Daily finance summary</label>
          </div>
          <div>
            <strong>Urgent only mode</strong>
            <label><input type="checkbox" checked={preferences.urgentOnly} onChange={(e) => savePreferences({ ...preferences, urgentOnly: e.target.checked })} /> Only highlight urgent billing issues</label>
          </div>
          {portal === 'accounting' && (
            <>
              <div>
                <strong>Payment alerts</strong>
                <label><input type="checkbox" checked={preferences.payments} onChange={(e) => savePreferences({ ...preferences, payments: e.target.checked })} /> Pending and successful payments</label>
              </div>
              <div>
                <strong>Billing alerts</strong>
                <label><input type="checkbox" checked={preferences.billing} onChange={(e) => savePreferences({ ...preferences, billing: e.target.checked })} /> Billing ticket updates</label>
              </div>
              <div>
                <strong>Subscription alerts</strong>
                <label><input type="checkbox" checked={preferences.subscriptions} onChange={(e) => savePreferences({ ...preferences, subscriptions: e.target.checked })} /> Recurring payment activity</label>
              </div>
              <div>
                <strong>Receipt alerts</strong>
                <label><input type="checkbox" checked={preferences.receipts} onChange={(e) => savePreferences({ ...preferences, receipts: e.target.checked })} /> Receipt-ready and refund activity</label>
              </div>
            </>
          )}
        </div>
        {preferenceStatus ? <div className="panel-note">{preferenceStatus}</div> : null}
      </div>

      <div className="panel">
        <div className="card-header">
          <div>
            <h3>Security & session</h3>
            <p>Lightweight controls for the current portal session.</p>
          </div>
        </div>
        <div className="detail-grid">
          <div><strong>Current session</strong><span>{portal === 'accounting' ? 'Finance access' : 'Support access'}</span></div>
          <div><strong>Browser notifications</strong><span>{preferences.browserAlerts ? 'Enabled' : 'Disabled'}</span></div>
          <div><strong>Digest mode</strong><span>{preferences.emailDigest ? 'Enabled' : 'Disabled'}</span></div>
          <div><strong>Recommended action</strong><span>Sign out after shared-device use</span></div>
        </div>
        <div className="pill-group">
          <button className="ghost" type="button" onClick={onLogout}>Sign out now</button>
        </div>
      </div>

      <div className="panel">
        <div className="card-header">
          <div>
            <h3>Recent portal activity</h3>
            <p>Quick visibility into the latest payment or billing events routed to this portal.</p>
          </div>
          {portal === 'accounting' && (
            <div className="pill-group">
              {['all', 'payments', 'billing', 'subscriptions', 'receipts'].map((value) => (
                <button
                  key={value}
                  className={`ghost ${activityFilter === value ? 'pill pill--active' : ''}`}
                  type="button"
                  onClick={() => setActivityFilter(value)}
                >
                  {value === 'all' ? 'All' : value}
                </button>
              ))}
            </div>
          )}
        </div>
        {activity.error && <div className="alert">{activity.error}</div>}
        <div className="support-history">
          {activity.loading ? (
            <div className="support-history__item">Loading activity…</div>
          ) : filteredRows.length === 0 ? (
            <div className="support-history__item">No recent activity yet.</div>
          ) : (
            filteredRows.map((row) => (
              <div key={row.id} className="support-history__item">
                <strong>{row.title}</strong>
                <span>{row.body || 'No extra detail provided.'}</span>
                <small>{formatNotificationTime(row.sent_at || row.created_at)}</small>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function AccountingBillingTicketsView() {
  return <SupportQueueView portalMode="accounting" ticketCategory="billing" />;
}

function CustomerSupportOverviewView() {
  const [summary, setSummary] = useState({ loading: true, error: '', queue: null, users: null, resolved: 0, dismissed: 0, waitingOnUser: 0, slaRisk: 0, billing: 0 });

  useEffect(() => {
    let cancelled = false;
    Promise.all([
      fetchSupportQueue({ status: 'pending', page: 1, perPage: 25 }),
      fetchSupportQueue({ status: 'resolved', page: 1, perPage: 25 }),
      fetchSupportQueue({ status: 'dismissed', page: 1, perPage: 25 }),
      fetchUsers({ page: 1, perPage: 25 }),
    ])
      .then(([queue, resolvedQueue, dismissedQueue, users]) => {
        if (cancelled) return;
        const rows = queue?.data || [];
        const tickets = rows.filter((row) => row?.type === 'support_ticket');
        const urgent = tickets.filter((row) => (row?.payload?.priority || '').toString().toLowerCase() === 'urgent').length;
        const waitingOnUser = tickets.filter((row) => {
          const messages = Array.isArray(row?.payload?.messages) ? row.payload.messages : [];
          const latest = messages[messages.length - 1];
          return latest?.sender_role === 'admin';
        }).length;
        const slaRisk = tickets.filter((row) => {
          const createdAt = new Date(row?.payload?.created_at || row?.created_at || 0).getTime();
          return createdAt > 0 && Date.now() - createdAt > 1000 * 60 * 60 * 24;
        }).length;
        const billing = tickets.filter((row) => (row?.payload?.category || '').toString().toLowerCase() === 'billing').length;
        setSummary({
          loading: false,
          error: '',
          queue: { total: queue?.meta?.total || rows.length, tickets: tickets.length, urgent },
          users: { total: users?.meta?.total || (users?.data || []).length },
          resolved: Number(resolvedQueue?.meta?.total || 0),
          dismissed: Number(dismissedQueue?.meta?.total || 0),
          waitingOnUser,
          slaRisk,
          billing,
        });
      })
      .catch((err) => {
        if (cancelled) return;
        setSummary({ loading: false, error: err.message || 'Failed to load customer support dashboard', queue: null, users: null, resolved: 0, dismissed: 0, waitingOnUser: 0, slaRisk: 0, billing: 0 });
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Customer support dashboard</h2>
          <p>Keep the queue moving while staying close to the people behind each request.</p>
        </div>
      </div>
      {summary.error && <div className="alert">{summary.error}</div>}
      <div className="detail-grid">
        <div className="metric">
          <span className="metric-label">Queue total</span>
          <strong>{summary.loading ? '—' : summary.queue?.total ?? 0}</strong>
          <small>Open support work</small>
        </div>
        <div className="metric">
          <span className="metric-label">Ticket threads</span>
          <strong>{summary.loading ? '—' : summary.queue?.tickets ?? 0}</strong>
          <small>Support conversations</small>
        </div>
        <div className="metric">
          <span className="metric-label">Urgent now</span>
          <strong>{summary.loading ? '—' : summary.queue?.urgent ?? 0}</strong>
          <small>Priority tickets to triage first</small>
        </div>
        <div className="metric">
          <span className="metric-label">Waiting on user</span>
          <strong>{summary.loading ? '—' : summary.waitingOnUser ?? 0}</strong>
          <small>Latest reply sent by support</small>
        </div>
        <div className="metric">
          <span className="metric-label">SLA risk</span>
          <strong>{summary.loading ? '—' : summary.slaRisk ?? 0}</strong>
          <small>Pending longer than 24 hours</small>
        </div>
        <div className="metric">
          <span className="metric-label">Billing escalations</span>
          <strong>{summary.loading ? '—' : summary.billing ?? 0}</strong>
          <small>Tickets that may need accounting</small>
        </div>
        <div className="metric">
          <span className="metric-label">Resolved</span>
          <strong>{summary.loading ? '—' : summary.resolved ?? 0}</strong>
          <small>Resolved ticket backlog</small>
        </div>
        <div className="metric">
          <span className="metric-label">Users visible</span>
          <strong>{summary.loading ? '—' : summary.users?.total ?? 0}</strong>
          <small>User directory available to support</small>
        </div>
      </div>
      <div className="card">
        <div className="card-title-row">
          <div>
            <h3>What to watch</h3>
            <p>Use Users for context and Tickets to reply, resolve, and keep the queue healthy.</p>
          </div>
        </div>
        <div className="detail-grid">
          <div><strong>Main workflow</strong><span>Users + ticket queue</span></div>
          <div><strong>Priority focus</strong><span>Urgent and high tickets</span></div>
          <div><strong>Goal</strong><span>Shorter first response time</span></div>
          <div><strong>Recommended review</strong><span>New replies and unresolved threads</span></div>
        </div>
      </div>
    </div>
  );
}

function AccountingPortal({ user, onLogout }) {
  const navItems = [
    { to: '/accounting/dashboard', label: 'Dashboard', icon: 'dashboard' },
    { to: '/accounting/transactions', label: 'Transactions', icon: 'transactions' },
    { to: '/accounting/failed-payments', label: 'Failed Payments', icon: 'failed' },
    { to: '/accounting/reconciliation', label: 'Reconciliation', icon: 'reconciliation' },
    { to: '/accounting/reports', label: 'Reports', icon: 'reports' },
    { to: '/accounting/receipts', label: 'Receipt Activity', icon: 'receipts' },
    { to: '/accounting/billing', label: 'Billing Tickets', icon: 'billing' },
    { to: '/accounting/subscriptions', label: 'Subscriptions', icon: 'subscriptions' },
    { to: '/accounting/account', label: 'My Account', icon: 'profile' },
  ];

  return (
    <SpecialistLayout
      user={user}
      onLogout={onLogout}
      title="Accounting Portal"
      subtitle="Receipts, payments, subscriptions, and billing support for the finance team."
      navItems={navItems}
      portal="accounting"
    >
      <Routes>
        <Route path="/accounting/dashboard" element={<AccountingOverviewView />} />
        <Route path="/accounting/transactions" element={<TransactionsView portalMode="accounting" />} />
        <Route path="/accounting/failed-payments" element={<AccountingFailedPaymentsView />} />
        <Route path="/accounting/reconciliation" element={<AccountingReconciliationView />} />
        <Route path="/accounting/reports" element={<AccountingReportsView />} />
        <Route path="/accounting/receipts" element={<ReceiptActivityView />} />
        <Route path="/accounting/billing" element={<AccountingBillingTicketsView />} />
        <Route path="/accounting/subscriptions" element={<SubscriptionsView />} />
        <Route path="/accounting/account" element={<SpecialistAccountView user={user} portal="accounting" onLogout={onLogout} />} />
        <Route path="*" element={<Navigate to="/accounting/dashboard" replace />} />
      </Routes>
    </SpecialistLayout>
  );
}

function SupportPortal({ user, onLogout, roleCatalog }) {
  const navItems = [
    { to: '/customer-support/dashboard', label: 'Dashboard', icon: 'dashboard' },
    { to: '/customer-support/users', label: 'Users', icon: 'profile' },
    { to: '/customer-support/tickets', label: 'Support Tickets', icon: 'billing' },
    { to: '/customer-support/account', label: 'My Account', icon: 'profile' },
  ];

  return (
    <SpecialistLayout
      user={user}
      onLogout={onLogout}
      title="Customer Support Portal"
      subtitle="User context and ticket workflows for the support team."
      navItems={navItems}
      portal="support"
    >
      <Routes>
        <Route path="/customer-support/dashboard" element={<CustomerSupportOverviewView />} />
        <Route path="/customer-support/users" element={<UsersView readOnly institutions={[]} roleCatalog={roleCatalog} />} />
        <Route path="/customer-support/tickets" element={<SupportQueueView portalMode="support" />} />
        <Route path="/customer-support/account" element={<SpecialistAccountView user={user} portal="support" onLogout={onLogout} />} />
        <Route path="*" element={<Navigate to="/customer-support/dashboard" replace />} />
      </Routes>
    </SpecialistLayout>
  );
}

function InstitutionCreateCard({ onCreated }) {
  const [name, setName] = useState('');
  const [status, setStatus] = useState('pending');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleCreate(e) {
    e.preventDefault();
    if (!name.trim()) return;
    setLoading(true);
    setError('');
    try {
      await createInstitution({ name: name.trim(), status });
      setName('');
      setStatus('pending');
      onCreated?.();
    } catch (err) {
      setError(err.message || 'Failed to create institution');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Create institution</h3>
      <p>Onboard a new school before alumni can register under it.</p>
      {error && <div className="alert">{error}</div>}
      <form className="card-form" onSubmit={handleCreate}>
        <input
          className="input"
          placeholder="Institution name"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
          {STATUS_OPTIONS.filter((opt) => opt.value).map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create'}
        </button>
      </form>
    </div>
  );
}

function InstitutionBulkImportCard({ onImported }) {
  const [sheetText, setSheetText] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState(null);

  const previewRows = useMemo(() => parseInstitutionImportSheet(sheetText), [sheetText]);

  function downloadTemplate() {
    const blob = new Blob([buildInstitutionImportTemplate()], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'institution-import-template.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  async function importRows() {
    if (!previewRows.length) {
      setError('Paste or upload at least one valid school row first.');
      return;
    }
    setLoading(true);
    setError('');
    setResult(null);
    try {
      const data = await bulkImportInstitutions(previewRows);
      setResult({
        count: data?.count || 0,
        skippedCount: data?.skipped_count || 0,
        errorCount: data?.error_count || 0,
        institutions: data?.institutions || [],
        report: data?.report || [],
      });
      setSheetText('');
      onImported?.();
    } catch (err) {
      setError(err.message || 'Failed to import schools');
    } finally {
      setLoading(false);
    }
  }

  function downloadSuccessCsv() {
    if (!result?.institutions?.length) return;
    const headers = ['id', 'school_id', 'name', 'status', 'website', 'email', 'phone', 'location', 'address', 'motto', 'description'];
    const lines = result.institutions.map((row) =>
      headers
        .map((key) => `"${String(row[key] ?? '').replace(/"/g, '""')}"`)
        .join(',')
    );
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'imported-schools.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  async function handleFile(event) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    try {
      const text = await file.text();
      setSheetText(text);
      setError('');
    } catch (_) {
      setError('Unable to read the selected sheet.');
    }
  }

  return (
    <div className="card">
      <h3>Bulk import schools</h3>
      <p>Upload or paste a CSV sheet. Imported schools are suspended by default until you activate them.</p>
      {error && <div className="alert">{error}</div>}
      {result && (
        <div className="alert success">
          <div className="institution-import-summary">
            <span>Imported {result.count}</span>
            <span>Skipped {result.skippedCount}</span>
            <span>Errors {result.errorCount}</span>
          </div>
          <div className="institution-import-toolbar">
            <button className="ghost ghost--sm" type="button" onClick={downloadSuccessCsv} disabled={!result.institutions.length}>
              Download imported CSV
            </button>
          </div>
          {!!result.institutions.length && (
            <div className="institution-import-report">
              {result.institutions.slice(0, 4).map((row) => (
                <div key={row.id} className="institution-import-report__row">
                  <strong>{row.name}</strong>
                  <span>{row.school_id}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
      <div className="card-form">
        <div className="institution-import-toolbar">
          <button className="ghost ghost--sm" type="button" onClick={downloadTemplate}>Download template</button>
          <label className="ghost ghost--sm institution-import-upload">
            Upload CSV
            <input type="file" accept=".csv,text/csv,.txt" onChange={handleFile} style={{ display: 'none' }} />
          </label>
        </div>
        <textarea
          className="textarea"
          rows="8"
          placeholder="Paste your CSV sheet here with columns: name, website, email, phone, location, address, motto, description"
          value={sheetText}
          onChange={(e) => setSheetText(e.target.value)}
        />
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <div>
            <strong>{previewRows.length}</strong> row{previewRows.length === 1 ? '' : 's'} ready
          </div>
          <button className="primary primary--sm" type="button" onClick={importRows} disabled={loading || !previewRows.length}>
            {loading ? 'Importing...' : 'Import schools'}
          </button>
        </div>
        {!!result?.report?.length && (
          <div className="institution-import-report institution-import-report--full">
            {result.report.map((row, index) => (
              <div key={`${row.row}-${index}`} className={`institution-import-report__row institution-import-report__row--${row.status}`}>
                <div>
                  <strong>Row {row.row}</strong> {row.name ? `— ${row.name}` : ''}
                </div>
                <span>{row.school_id || row.message}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function InstitutionsView({ refreshKey }) {
  const [status, setStatus] = useState('pending');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState(null);
  const [editingData, setEditingData] = useState(null);
  const [savingProfile, setSavingProfile] = useState(false);
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [bulkLoading, setBulkLoading] = useState(false);

  const queryKey = useMemo(() => `${status}|${search}|${page}`, [status, search, page]);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchInstitutions({ status, search, page, perPage: 15 });
      const list = data?.data || data?.institutions || [];
      setRows(list);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load institutions');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [queryKey, refreshKey]);

  useEffect(() => {
    setSelectedIds(new Set());
  }, [status, search, page, refreshKey]);

  async function handleStatusChange(id, nextStatus) {
    try {
      await updateInstitutionStatus(id, nextStatus);
      setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status: nextStatus } : r)));
    } catch (err) {
      setError(err.message || 'Failed to update status');
    }
  }

  async function openProfile(id) {
    setEditing(id);
    setEditingData(null);
    try {
      const res = await fetchInstitutionProfile(id);
      setEditingData(res?.institution || null);
    } catch (err) {
      setError(err.message || 'Failed to load institution');
      setEditing(null);
    }
  }

  function exportCsv() {
    if (!rows.length) return;
    const headers = ['id', 'school_id', 'name', 'slug', 'status', 'website', 'email', 'phone', 'location', 'address', 'motto', 'description'];
    const lines = rows.map((row) => {
      return [row.id, row.school_id, row.name, row.slug, row.status, row.website, row.email, row.phone, row.location, row.address, row.motto, row.description]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'institutions.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  function toggleSelection(id) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    setSelectedIds((prev) => {
      if (rows.length > 0 && prev.size === rows.length) return new Set();
      return new Set(rows.map((row) => row.id));
    });
  }

  async function handleBulkStatusChange(nextStatus) {
    if (!selectedIds.size) return;
    setBulkLoading(true);
    setError('');
    try {
      await Promise.all(Array.from(selectedIds).map((id) => updateInstitutionStatus(id, nextStatus)));
      setRows((prev) => prev.map((row) => (selectedIds.has(row.id) ? { ...row, status: nextStatus } : row)));
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Failed to update institutions');
    } finally {
      setBulkLoading(false);
    }
  }

  return (
    <div className="panel reports-page">
      <div className="panel-header">
        <div>
          <h2>Institutions</h2>
          <p>Approve schools before alumni can join.</p>
        </div>
        <div className="panel-actions">
          <input
            className="input"
            placeholder="Search institutions"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
          <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
            {STATUS_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
          <button className="ghost" onClick={exportCsv} disabled={!rows.length}>Export CSV</button>
        </div>
      </div>

      {error && <div className="alert">{error}</div>}

      {selectedIds.size > 0 && (
        <div className="bulk-actions">
          <div className="bulk-count">{selectedIds.size} selected</div>
          <button className="primary" onClick={() => handleBulkStatusChange('active')} disabled={bulkLoading}>
            {bulkLoading ? 'Updating...' : 'Re-activate selected'}
          </button>
          <button className="ghost" onClick={() => handleBulkStatusChange('suspended')} disabled={bulkLoading}>
            Suspend selected
          </button>
        </div>
      )}

      <div className="table table--selectable">
        <div className="table-row table-row--head">
          <div>
            <input
              type="checkbox"
              checked={rows.length > 0 && selectedIds.size === rows.length}
              onChange={toggleAll}
            />
          </div>
          <div>Name</div>
          <div>School ID</div>
          <div>Status</div>
          <div>Admins</div>
          <div>Members</div>
          <div>Created</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No institutions found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div>
                <input
                  type="checkbox"
                  checked={selectedIds.has(row.id)}
                  onChange={() => toggleSelection(row.id)}
                />
              </div>
              <div className="title-cell">
                <strong>{row.name}</strong>
                <span>{row.slug}</span>
              </div>
              <div>{row.school_id || '-'}</div>
              <div><StatusPill status={row.status} /></div>
              <div>{row.admins_count ?? 0}</div>
              <div>{row.users_count ?? 0}</div>
              <div>{row.created_at ? new Date(row.created_at).toLocaleDateString() : '-'}</div>
              <div className="actions">
                <button className="ghost" onClick={() => openProfile(row.id)}>Edit profile</button>
                {row.status === 'pending' && (
                  <>
                    <button className="primary" onClick={() => handleStatusChange(row.id, 'active')}>Approve</button>
                    <button className="ghost" onClick={() => handleStatusChange(row.id, 'rejected')}>Reject</button>
                  </>
                )}
                {row.status === 'active' && (
                  <button className="ghost" onClick={() => handleStatusChange(row.id, 'suspended')}>Suspend</button>
                )}
                {row.status === 'suspended' && (
                  <button className="primary" onClick={() => handleStatusChange(row.id, 'active')}>Re-activate</button>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>

      {editing && (
        <div className="modal-backdrop" onClick={() => setEditing(null)}>
          <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">Institution profile</div>
            <div className="modal-message">
              {editingData ? (
                <div className="modal-form">
                  <input className="input" placeholder="School ID" value={editingData.school_id || ''} readOnly />
                  <input className="input" placeholder="Name" value={editingData.name || ''} onChange={(e) => setEditingData({ ...editingData, name: e.target.value })} />
                  <input className="input" placeholder="Website" value={editingData.website || ''} onChange={(e) => setEditingData({ ...editingData, website: e.target.value })} />
                  <input className="input" placeholder="Email" value={editingData.email || ''} onChange={(e) => setEditingData({ ...editingData, email: e.target.value })} />
                  <input className="input" placeholder="Phone" value={editingData.phone || ''} onChange={(e) => setEditingData({ ...editingData, phone: e.target.value })} />
                  <input className="input" placeholder="Location" value={editingData.location || ''} onChange={(e) => setEditingData({ ...editingData, location: e.target.value })} />
                  <input className="input" placeholder="Address" value={editingData.address || ''} onChange={(e) => setEditingData({ ...editingData, address: e.target.value })} />
                  <input className="input" placeholder="Motto" value={editingData.motto || ''} onChange={(e) => setEditingData({ ...editingData, motto: e.target.value })} />
                  <div className="file-row">
                    <input className="input" placeholder="Logo" value={editingData.logo_url || ''} readOnly />
                    <div className="upload-thumb">
                      {editingData.logo_url ? <img src={resolveMediaUrl(editingData.logo_url)} alt="Logo preview" /> : 'Logo'}
                    </div>
                    <label className="file-upload">
                      <input
                        type="file"
                        accept="image/png,image/jpeg"
                        onChange={async (e) => {
                          const file = e.target.files?.[0];
                          e.target.value = '';
                          if (!file) return;
                          if (!['image/png', 'image/jpeg'].includes(file.type)) {
                            setError('Only PNG or JPG images are allowed.');
                            return;
                          }
                          if (file.size > 2 * 1024 * 1024) {
                            setError('File is too large. Max size is 2MB.');
                            return;
                          }
                          try {
                            const data = await uploadAdminMedia(file);
                            if (data?.url) {
                              setEditingData({ ...editingData, logo_url: data.url });
                            }
                          } catch (err) {
                            setError(err.message || 'Upload failed');
                          }
                        }}
                      />
                      Upload logo
                    </label>
                  </div>
                  <div className="file-row">
                    <input className="input" placeholder="Banner" value={editingData.banner_url || ''} readOnly />
                    <div className="upload-thumb">
                      {editingData.banner_url ? <img src={resolveMediaUrl(editingData.banner_url)} alt="Banner preview" /> : 'Banner'}
                    </div>
                    <label className="file-upload">
                      <input
                        type="file"
                        accept="image/png,image/jpeg"
                        onChange={async (e) => {
                          const file = e.target.files?.[0];
                          e.target.value = '';
                          if (!file) return;
                          if (!['image/png', 'image/jpeg'].includes(file.type)) {
                            setError('Only PNG or JPG images are allowed.');
                            return;
                          }
                          if (file.size > 2 * 1024 * 1024) {
                            setError('File is too large. Max size is 2MB.');
                            return;
                          }
                          try {
                            const data = await uploadAdminMedia(file);
                            if (data?.url) {
                              setEditingData({ ...editingData, banner_url: data.url });
                            }
                          } catch (err) {
                            setError(err.message || 'Upload failed');
                          }
                        }}
                      />
                      Upload banner
                    </label>
                  </div>
                  <textarea className="textarea" rows="4" placeholder="Description" value={editingData.description || ''} onChange={(e) => setEditingData({ ...editingData, description: e.target.value })} />
                </div>
              ) : (
                <div>Loading...</div>
              )}
            </div>
            <div className="modal-actions">
              <button className="ghost" onClick={() => setEditing(null)}>Cancel</button>
              <button
                className="primary"
                onClick={async () => {
                  if (!editingData) return;
                  setSavingProfile(true);
                  try {
                    const res = await updateInstitutionProfile(editing, editingData);
                    const updated = res?.institution;
                    if (updated) {
                      setRows((prev) => prev.map((r) => (r.id === updated.id ? { ...r, name: updated.name } : r)));
                    }
                    setEditing(null);
                  } catch (err) {
                    setError(err.message || 'Failed to update institution');
                  } finally {
                    setSavingProfile(false);
                  }
                }}
                disabled={savingProfile}
              >
                {savingProfile ? 'Saving...' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function UsersView({ allowHardDelete, institutions = [], readOnly = false, roleCatalog = BUILTIN_ROLE_CATALOG }) {
  const [search, setSearch] = useState('');
  const [role, setRole] = useState('');
  const [status, setStatus] = useState('');
  const [institutionFilter, setInstitutionFilter] = useState('');
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [guardState, setGuardState] = useState({ open: false, mode: 'bulk', targetId: null });
  const [editingUser, setEditingUser] = useState(null);
  const [createAdminOpen, setCreateAdminOpen] = useState(false);
  const [bulkRole, setBulkRole] = useState('');
  const [bulkStatus, setBulkStatus] = useState('');
  const [bulkInstitution, setBulkInstitution] = useState('');
  const [bulkLoading, setBulkLoading] = useState(false);
  const [bulkConfirm, setBulkConfirm] = useState({ open: false });
  const [openMenuId, setOpenMenuId] = useState(null);
  const [viewUser, setViewUser] = useState(null);
  const roleOptions = useMemo(() => ([
    { key: 'alumni', label: 'Alumni' },
    ...Object.entries(roleCatalog || {}).map(([key, value]) => ({
      key,
      label: value?.label || key,
    })),
  ]), [roleCatalog]);

  const queryKey = useMemo(
    () => `${search}|${role}|${status}|${institutionFilter}|${page}`,
    [search, role, status, institutionFilter, page],
  );

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchUsers({
        search,
        role,
        status,
        institutionId: institutionFilter ? Number(institutionFilter) : undefined,
        page,
        perPage: 15,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [queryKey]);

  useEffect(() => {
    setSelectedIds(new Set());
  }, [page]);

  async function handleToggle(user) {
    try {
      if (user.status === 'suspended') {
        await reactivateUser(user.id);
        setRows((prev) => prev.map((u) => (u.id === user.id ? { ...u, status: 'active' } : u)));
      } else {
        await suspendUser(user.id);
        setRows((prev) => prev.map((u) => (u.id === user.id ? { ...u, status: 'suspended' } : u)));
      }
    } catch (err) {
      setError(err.message || 'Failed to update user');
    }
  }

  function toggleSelection(id) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  useEffect(() => {
    function handleClick(e) {
      const target = e.target;
      if (target instanceof Element) {
        if (target.closest('.action-menu') || target.closest('.table-row')) {
          return;
        }
      }
      setOpenMenuId(null);
    }
    if (openMenuId == null) return () => {};
    document.addEventListener('click', handleClick);
    return () => document.removeEventListener('click', handleClick);
  }, [openMenuId]);

  function toggleAll() {
    setSelectedIds((prev) => {
      if (prev.size === rows.length) return new Set();
      return new Set(rows.map((r) => r.id));
    });
  }

  function confirmBulkDelete() {
    if (!selectedIds.size) return;
    setGuardState({
      open: true,
      mode: 'bulk',
      title: 'Bulk delete users',
      message: `This will permanently delete ${selectedIds.size} users. This action cannot be undone.`,
      confirmLabel: 'Delete',
      targetId: null,
    });
  }

  function confirmSingleDelete(id) {
    setGuardState({
      open: true,
      mode: 'single',
      title: 'Delete user',
      message: 'This will permanently delete the user and cannot be undone.',
      confirmLabel: 'Delete',
      targetId: id,
    });
  }

  async function handleDelete() {
    const mode = guardState.mode;
    const targetId = guardState.targetId;
    setGuardState({ open: false, mode: 'bulk', targetId: null });
    try {
      if (mode === 'single' && targetId) {
        await purgeUser(targetId);
        setRows((prev) => prev.filter((r) => r.id !== targetId));
        setSelectedIds((prev) => {
          const next = new Set(prev);
          next.delete(targetId);
          return next;
        });
        return;
      }
      const ids = Array.from(selectedIds);
      await Promise.all(ids.map((id) => purgeUser(id)));
      setRows((prev) => prev.filter((r) => !selectedIds.has(r.id)));
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Failed to delete users');
    }
  }

  async function handleBulkUpdate() {
    if (!selectedIds.size) return;
    const payload = {
      role: bulkRole || null,
      status: bulkStatus || null,
      institution_id: bulkInstitution ? Number(bulkInstitution) : null,
    };
    if (payload.role === 'institution_admin' && !payload.institution_id) {
      setError('Institution is required for institution admins');
      return;
    }
    const updates = Object.fromEntries(Object.entries(payload).filter(([, v]) => v !== null));
    if (!Object.keys(updates).length) return;
    setBulkLoading(true);
    setError('');
    try {
      const ids = Array.from(selectedIds);
      await Promise.all(ids.map((id) => updateUserAdmin(id, updates)));
      setRows((prev) =>
        prev.map((row) =>
          selectedIds.has(row.id)
            ? {
                ...row,
                role: updates.role ?? row.role,
                status: updates.status ?? row.status,
                institution: updates.institution_id
                  ? institutions.find((i) => i.id === updates.institution_id) || row.institution
                  : updates.institution_id === null
                    ? null
                    : row.institution,
              }
            : row
        )
      );
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Failed to update users');
    } finally {
      setBulkLoading(false);
    }
  }

  async function handleBulkStatus(nextStatus) {
    if (!selectedIds.size) return;
    setBulkLoading(true);
    setError('');
    try {
      const ids = Array.from(selectedIds);
      await Promise.all(ids.map((id) => updateUserAdmin(id, { status: nextStatus })));
      setRows((prev) =>
        prev.map((row) =>
          selectedIds.has(row.id)
            ? {
                ...row,
                status: nextStatus,
              }
            : row
        )
      );
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Failed to update users');
    } finally {
      setBulkLoading(false);
    }
  }

  function confirmBulkUpdate() {
    if (!selectedIds.size) return;
    setBulkConfirm({
      open: true,
      title: 'Apply bulk updates',
      message: `Apply selected changes to ${selectedIds.size} users?`,
      confirmLabel: 'Apply',
      onConfirm: async () => {
        setBulkConfirm({ open: false });
        await handleBulkUpdate();
      },
    });
  }

  function confirmBulkStatus(nextStatus) {
    if (!selectedIds.size) return;
    const label = nextStatus === 'suspended' ? 'Suspend' : 'Activate';
    setBulkConfirm({
      open: true,
      title: `${label} users`,
      message: `${label} ${selectedIds.size} selected users?`,
      confirmLabel: label,
      onConfirm: async () => {
        setBulkConfirm({ open: false });
        await handleBulkStatus(nextStatus);
      },
    });
  }

  function exportCsv() {
    if (!rows.length) return;
    const headers = ['id', 'name', 'email', 'role', 'status', 'institution'];
    const lines = rows.map((row) => {
      const institution = row.institution?.name || '';
      return [row.id, row.name, row.email, row.role, row.status, institution]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'users.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  async function exportInstitutionCsv() {
    if (!institutionFilter) return;
    setLoading(true);
    setError('');
    try {
      const allRows = [];
      let currentPage = 1;
      let lastPage = 1;
      do {
        const data = await fetchUsers({
          search,
          role,
          status,
          institutionId: Number(institutionFilter),
          page: currentPage,
          perPage: 50,
        });
        const batch = data?.data || [];
        allRows.push(...batch);
        lastPage = data?.meta?.last_page || currentPage;
        currentPage += 1;
      } while (currentPage <= lastPage);

      if (!allRows.length) return;
      const headers = ['id', 'name', 'email', 'role', 'status', 'institution'];
      const lines = allRows.map((row) => {
        const institution = row.institution?.name || '';
        return [row.id, row.name, row.email, row.role, row.status, institution]
          .map((v) => `"${String(v).replace(/"/g, '""')}"`)
          .join(',');
      });
      const csv = [headers.join(','), ...lines].join('\n');
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      const instName = institutions.find((i) => i.id === Number(institutionFilter))?.name || 'institution';
      link.setAttribute('download', `users-${instName.replace(/\s+/g, '_').toLowerCase()}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      setError(err.message || 'Failed to export users');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="panel reports-page">
      <div className="panel-header">
        <div>
          <h2>Users</h2>
          <p>Search and manage platform accounts.</p>
        </div>
        <div className="panel-actions">
          <input
            className="input"
            placeholder="Search users"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
          {allowHardDelete && !readOnly && (
            <button className="primary" onClick={() => setCreateAdminOpen(true)}>
              Add admin
            </button>
          )}
          {institutions.length > 0 && (
            <select
              className="select"
              value={institutionFilter}
              onChange={(e) => {
                setInstitutionFilter(e.target.value);
                setPage(1);
              }}
            >
              <option value="">All institutions</option>
              {institutions.map((inst) => (
                <option key={inst.id} value={inst.id}>{inst.name}</option>
              ))}
            </select>
          )}
          <select className="select" value={role} onChange={(e) => setRole(e.target.value)}>
            <option value="">All roles</option>
            {roleOptions.map((option) => (
              <option key={option.key} value={option.key}>{option.label}</option>
            ))}
          </select>
          <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All status</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </select>
          <button className="ghost" onClick={exportCsv} disabled={!rows.length}>Export CSV</button>
          <button className="ghost" onClick={exportInstitutionCsv} disabled={!institutionFilter || loading}>
            Export institution CSV
          </button>
        </div>
      </div>

      {allowHardDelete && !readOnly && selectedIds.size > 0 && (
        <div className="bulk-actions">
          <div className="bulk-count">{selectedIds.size} selected</div>
          <select className="select" value={bulkRole} onChange={(e) => setBulkRole(e.target.value)}>
            <option value="">Set role</option>
            {roleOptions.map((option) => (
              <option key={option.key} value={option.key}>{option.label}</option>
            ))}
          </select>
          <select className="select" value={bulkInstitution} onChange={(e) => setBulkInstitution(e.target.value)} disabled={!institutions.length}>
            <option value="">Set institution</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
          <select className="select" value={bulkStatus} onChange={(e) => setBulkStatus(e.target.value)}>
            <option value="">Set status</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </select>
          <button className="ghost" onClick={confirmBulkUpdate} disabled={bulkLoading}>
            {bulkLoading ? 'Applying...' : 'Apply'}
          </button>
          <button className="ghost" onClick={() => confirmBulkStatus('active')} disabled={bulkLoading}>
            Activate selected
          </button>
          <button className="ghost" onClick={() => confirmBulkStatus('suspended')} disabled={bulkLoading}>
            Suspend selected
          </button>
          <button className="ghost danger" onClick={confirmBulkDelete}>Bulk delete</button>
        </div>
      )}

      {error && <div className="alert">{error}</div>}

      <div className={`table table--users ${allowHardDelete && !readOnly ? 'table--selectable' : ''}`}>
        <div className="table-row table-row--head">
          {allowHardDelete && !readOnly && (
            <div>
              <input
                type="checkbox"
                checked={rows.length > 0 && selectedIds.size === rows.length}
                onChange={toggleAll}
              />
            </div>
          )}
          <div>Name</div>
          <div>Email</div>
          <div>Role</div>
          <div>Institution</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No users found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              {allowHardDelete && !readOnly && (
                <div>
                  <input
                    type="checkbox"
                    checked={selectedIds.has(row.id)}
                    onChange={() => toggleSelection(row.id)}
                  />
                </div>
              )}
              <div>{row.name}</div>
              <div>{row.email}</div>
              <div>{row.role}</div>
              <div>{row.institution?.name || '-'}</div>
              <div><StatusPill status={row.status} /></div>
              <div className="actions">
                <div className="action-menu">
                  <button
                    className="ghost"
                    onClick={(e) => {
                      e.stopPropagation();
                      setOpenMenuId((prev) => (prev === row.id ? null : row.id));
                    }}
                  >
                    Manage
                  </button>
                  {openMenuId === row.id && (
                    <div className="action-menu-list" onClick={(e) => e.stopPropagation()}>
                      <button className="ghost" onClick={() => { setViewUser(row); setOpenMenuId(null); }}>
                        [i] View details
                      </button>
                      {!readOnly && (
                        <button className="ghost" onClick={() => { setEditingUser(row); setOpenMenuId(null); }}>
                          [e] Edit user
                        </button>
                      )}
                      {!readOnly && (
                        <button className="ghost" onClick={() => { handleToggle(row); setOpenMenuId(null); }}>
                          {row.status === 'suspended' ? 'Reactivate' : 'Suspend'}
                        </button>
                      )}
                      {allowHardDelete && !readOnly && (
                        <button className="ghost danger" onClick={() => { confirmSingleDelete(row.id); setOpenMenuId(null); }}>
                          [x] Delete
                        </button>
                      )}
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>

      <GuardedModal
        open={guardState.open}
        title={guardState.title}
        message={guardState.message}
        confirmLabel={guardState.confirmLabel}
        guardText="DELETE"
        onCancel={() => setGuardState({ open: false, mode: 'bulk', targetId: null })}
        onConfirm={handleDelete}
      />
      <ConfirmModal
        open={bulkConfirm.open}
        title={bulkConfirm.title}
        message={bulkConfirm.message}
        confirmLabel={bulkConfirm.confirmLabel}
        onCancel={() => setBulkConfirm({ open: false })}
        onConfirm={bulkConfirm.onConfirm}
      />
      {!readOnly && (
        <EditUserModal
          open={!!editingUser}
          user={editingUser}
          institutions={institutions}
          roleCatalog={roleCatalog}
          onClose={() => setEditingUser(null)}
          onSaved={(payload) => {
            setRows((prev) =>
              prev.map((u) =>
                u.id === editingUser?.id
                  ? {
                      ...u,
                      role: payload.role ?? u.role,
                      status: payload.status ?? u.status,
                      institution: payload.institution_id
                        ? institutions.find((i) => i.id === payload.institution_id) || u.institution
                        : null,
                    }
                  : u
              )
            );
            setEditingUser(null);
          }}
        />
      )}
      {!readOnly && (
        <CreateAdminModal
          open={createAdminOpen}
          institutions={institutions}
          roleCatalog={roleCatalog}
          onClose={() => setCreateAdminOpen(false)}
          onCreated={(user) => {
            if (user) {
              setRows((prev) => [user, ...prev]);
            }
            setCreateAdminOpen(false);
          }}
        />
      )}
      {viewUser && (
        <div className="modal-backdrop" onClick={() => setViewUser(null)}>
          <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">User details</div>
            <div className="modal-message">{viewUser.name}</div>
            <div className="card-form">
              <div><strong>Email:</strong> {viewUser.email}</div>
              <div><strong>Role:</strong> {viewUser.role}</div>
              <div><strong>Status:</strong> {viewUser.status}</div>
              <div><strong>Institution:</strong> {viewUser.institution?.name || '-'}</div>
            </div>
            <div className="modal-actions">
              <button className="primary" onClick={() => setViewUser(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function AnalyticsCard({ title, value, subtitle, chartType, onClick }) {
  const primary = typeof window !== 'undefined'
    ? getComputedStyle(document.documentElement).getPropertyValue('--admin-secondary').trim() || '#0ea5e9'
    : '#0ea5e9';
  const labels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'];
  const dataset = buildSeries(typeof value === 'string' ? parseFloat(value.replace(/[^\d.]/g, '')) : value);
  const data = {
    labels,
    datasets: [
      {
        label: title,
        data: dataset,
        borderColor: primary,
        backgroundColor: `${primary}33`,
        tension: 0.35,
      },
    ],
  };
  const options = {
    responsive: true,
    plugins: { legend: { display: false } },
    scales: { x: { display: false }, y: { display: false } },
  };

  return (
    <div
      className={`metric${onClick ? ' metric--clickable' : ''}`}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={
        onClick
          ? (e) => {
              if (e.key === 'Enter' || e.key === ' ') onClick();
            }
          : undefined
      }
    >
      <div className="metric-title">{title}</div>
      <div className="metric-value">{value}</div>
      <div className="metric-subtitle">{subtitle}</div>
      <div className="chart">{chartType === 'bar' ? <Bar data={data} options={options} /> : <Line data={data} options={options} />}</div>
    </div>
  );
}

function ContentPerformanceTable({ institutionId }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [previewPost, setPreviewPost] = useState(null);
  const [filters, setFilters] = useState({
    from: '',
    to: '',
    minReactions: '',
  });

  useEffect(() => {
    setLoading(true);
    setError('');
    fetchContentPerformance({
      institutionId,
      from: filters.from || undefined,
      to: filters.to || undefined,
      minReactions: filters.minReactions ? Number(filters.minReactions) : undefined,
    })
      .then((res) => setRows(res?.data || []))
      .catch((err) => setError(err.message || 'Failed to load content performance'))
      .finally(() => setLoading(false));
  }, [institutionId, filters.from, filters.to, filters.minReactions]);

  return (
    <div className="panel reports-page">
      <div className="panel-header">
        <div>
          <h3>Top content</h3>
          <p>Most engaged posts (last 20).</p>
        </div>
        <div className="panel-actions">
          <button
            className="ghost"
            onClick={() => {
              if (!rows.length) return;
              const header = ['Author', 'Content', 'Reactions', 'Comments', 'Reports'];
              const csv = [
                header.join(','),
                ...rows.map((row) => [
                  `"${(row.user?.name || '').replace(/"/g, '""')}"`,
                  `"${(row.content || '').replace(/"/g, '""')}"`,
                  row.reactions_count ?? 0,
                  row.comments_count ?? 0,
                  row.reports_count ?? 0,
                ].join(',')),
              ].join('\n');
              const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
              const url = URL.createObjectURL(blob);
              const link = document.createElement('a');
              link.href = url;
              link.setAttribute('download', 'top-content.csv');
              document.body.appendChild(link);
              link.click();
              document.body.removeChild(link);
            }}
            disabled={!rows.length}
          >
            Export CSV
          </button>
        </div>
      </div>
      <div className="card-form card-form--wide">
        <input
          className="input"
          type="date"
          value={filters.from}
          onChange={(e) => setFilters({ ...filters, from: e.target.value })}
        />
        <input
          className="input"
          type="date"
          value={filters.to}
          onChange={(e) => setFilters({ ...filters, to: e.target.value })}
        />
        <input
          className="input"
          type="number"
          placeholder="Min reactions"
          value={filters.minReactions}
          onChange={(e) => setFilters({ ...filters, minReactions: e.target.value })}
        />
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="table table--wide table--payments">
        <div className="table-row table-row--head">
          <div>Author</div>
          <div>Content</div>
          <div>Reactions</div>
          <div>Comments</div>
          <div>Reports</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No posts available.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row table-row--clickable" key={row.id} onClick={() => setPreviewPost(row)}>
              <div>{row.user?.name || '-'}</div>
              <div className="truncate">{row.content || 'Shared a post'}</div>
              <div>{row.reactions_count ?? 0}</div>
              <div>{row.comments_count ?? 0}</div>
              <div>{row.reports_count ?? 0}</div>
            </div>
          ))
        )}
      </div>
      <PostPreviewModal open={!!previewPost} post={previewPost} onClose={() => setPreviewPost(null)} />
    </div>
  );
}

function SuperAnalyticsView() {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [range, setRange] = useState({ from: '', to: '' });

  useEffect(() => {
    setLoading(true);
    fetchPlatformAnalytics({
      from: range.from || undefined,
      to: range.to || undefined,
    })
      .then((res) => setData(res))
      .catch((err) => setError(err.message || 'Failed to load analytics'))
      .finally(() => setLoading(false));
  }, [range.from, range.to]);

  if (loading) return <div className="panel">Loading analytics...</div>;
  if (error) return <div className="panel"><div className="alert">{error}</div></div>;

  const metrics = data?.metrics || {};
  return (
    <>
      <div className="panel">
        <div className="panel-header">
          <div>
            <h2>Platform analytics</h2>
            <p>Overview of usage and revenue.</p>
          </div>
          <div className="panel-actions">
            <input
              className="input"
              type="date"
              value={range.from}
              onChange={(e) => setRange({ ...range, from: e.target.value })}
            />
            <input
              className="input"
              type="date"
              value={range.to}
              onChange={(e) => setRange({ ...range, to: e.target.value })}
            />
            <button
              className="ghost"
              onClick={() => {
                const headers = ['metric', 'value'];
                const lines = Object.entries(metrics).map(([key, value]) => `"${key}","${value ?? 0}"`);
                const csv = [headers.join(','), ...lines].join('\n');
                const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
                const url = URL.createObjectURL(blob);
                const link = document.createElement('a');
                link.href = url;
                link.setAttribute('download', 'platform-analytics.csv');
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
              }}
              disabled={!Object.keys(metrics).length}
            >
              Export metrics
            </button>
          </div>
        </div>
        <div className="metrics-grid">
          <AnalyticsCard title="Users" value={metrics.users_total ?? 0} subtitle="Total" chartType="line" />
          <AnalyticsCard title="Institutions" value={metrics.institutions_total ?? 0} subtitle="Total" chartType="bar" />
          <AnalyticsCard title="Posts" value={metrics.posts_total ?? 0} subtitle="Total" chartType="line" />
          <AnalyticsCard title="Events" value={metrics.events_total ?? 0} subtitle="Total" chartType="bar" />
          <AnalyticsCard title="Revenue" value={formatCurrency('GHS', metrics.revenue_total ?? 0)} subtitle="Paid fees" chartType="line" />
          <AnalyticsCard title="Donations" value={formatCurrency('GHS', metrics.donations_total ?? 0)} subtitle="All time" chartType="bar" />
        </div>
      </div>
      <ContentPerformanceTable />
    </>
  );
}

function InstitutionAnalyticsView({ institutionId }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [range, setRange] = useState({ from: '', to: '' });

  useEffect(() => {
    if (!institutionId) return;
    setLoading(true);
    fetchInstitutionAnalytics(institutionId, {
      from: range.from || undefined,
      to: range.to || undefined,
    })
      .then((res) => setData(res))
      .catch((err) => setError(err.message || 'Failed to load analytics'))
      .finally(() => setLoading(false));
  }, [institutionId, range.from, range.to]);

  if (!institutionId) return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;
  if (loading) return <div className="panel">Loading analytics...</div>;
  if (error) return <div className="panel"><div className="alert">{error}</div></div>;

  const metrics = data?.metrics || {};
  return (
    <>
      <div className="panel">
        <div className="panel-header">
          <div>
            <h2>Institution analytics</h2>
            <p>Engagement and growth for this institution.</p>
          </div>
          <div className="panel-actions">
            <input
              className="input"
              type="date"
              value={range.from}
              onChange={(e) => setRange({ ...range, from: e.target.value })}
            />
            <input
              className="input"
              type="date"
              value={range.to}
              onChange={(e) => setRange({ ...range, to: e.target.value })}
            />
            <button
              className="ghost"
              onClick={() => {
                const headers = ['metric', 'value'];
                const lines = Object.entries(metrics).map(([key, value]) => `"${key}","${value ?? 0}"`);
                const csv = [headers.join(','), ...lines].join('\n');
                const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
                const url = URL.createObjectURL(blob);
                const link = document.createElement('a');
                link.href = url;
                link.setAttribute('download', 'institution-analytics.csv');
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
              }}
              disabled={!Object.keys(metrics).length}
            >
              Export metrics
            </button>
          </div>
        </div>
        <div className="metrics-grid">
          <AnalyticsCard title="Users" value={metrics.users_total ?? 0} subtitle="Members" chartType="line" />
          <AnalyticsCard title="Posts" value={metrics.posts_total ?? 0} subtitle="Total" chartType="bar" />
          <AnalyticsCard title="Stories" value={metrics.stories_total ?? 0} subtitle="Total" chartType="line" />
          <AnalyticsCard title="Events" value={metrics.events_total ?? 0} subtitle="Total" chartType="bar" />
          <AnalyticsCard title="Donations" value={formatCurrency('GHS', metrics.donations_total ?? 0)} subtitle="Raised" chartType="line" />
          <AnalyticsCard title="Engagement" value={metrics.engagement_events_30d ?? 0} subtitle="Last 30d" chartType="bar" />
        </div>
      </div>
      <ContentPerformanceTable institutionId={institutionId} />
    </>
  );
}

function CreateEventCard({ institutionId, onCreated }) {
  const [title, setTitle] = useState('');
  const [eventType, setEventType] = useState('physical');
  const [startsAt, setStartsAt] = useState('');
  const [location, setLocation] = useState('');
  const [meetingUrl, setMeetingUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim() || !startsAt) return;
    setLoading(true);
    setError('');
    try {
      await createEvent({
        title: title.trim(),
        event_type: eventType,
        starts_at: new Date(startsAt).toISOString(),
        location: eventType === 'virtual' ? null : (location.trim() || null),
        meeting_url: eventType === 'physical' ? null : (meetingUrl.trim() || null),
        institution_id: institutionId || undefined,
      });
      setTitle('');
      setStartsAt('');
      setLocation('');
      setMeetingUrl('');
      onCreated?.();
    } catch (err) {
      setError(err.message || 'Failed to create event');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Create event</h3>
      <p>Schedule a new event for your community.</p>
      {error && <div className="alert">{error}</div>}
      <form className="card-form card-form--wide" onSubmit={handleSubmit}>
        <input className="input" placeholder="Event title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <select className="select" value={eventType} onChange={(e) => setEventType(e.target.value)}>
          <option value="physical">Physical</option>
          <option value="virtual">Virtual</option>
          <option value="fair">Fair</option>
          <option value="workshop">Workshop</option>
        </select>
        <input className="input" type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} />
        {(eventType === 'physical' || eventType === 'fair' || eventType === 'workshop') && (
          <input
            className="input"
            placeholder="Location"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
          />
        )}
        {(eventType === 'virtual' || eventType === 'fair' || eventType === 'workshop') && (
          <input
            className="input"
            placeholder="Meeting URL"
            value={meetingUrl}
            onChange={(e) => setMeetingUrl(e.target.value)}
          />
        )}
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create'}
        </button>
      </form>
    </div>
  );
}

function EditEventCard({ event, onSaved, onCancel }) {
  const [title, setTitle] = useState(event?.title || '');
  const [eventType, setEventType] = useState(event?.event_type || 'physical');
  const [startsAt, setStartsAt] = useState(event?.starts_at ? event.starts_at.slice(0, 16) : '');
  const [location, setLocation] = useState(event?.location || '');
  const [meetingUrl, setMeetingUrl] = useState(event?.meeting_url || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim() || !startsAt) return;
    setLoading(true);
    setError('');
    try {
      await updateEvent(event.id, {
        title: title.trim(),
        event_type: eventType,
        starts_at: new Date(startsAt).toISOString(),
        location: eventType === 'virtual' ? null : (location.trim() || null),
        meeting_url: eventType === 'physical' ? null : (meetingUrl.trim() || null),
      });
      onSaved?.();
    } catch (err) {
      setError(err.message || 'Failed to update event');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <div className="card-title-row">
        <div>
          <h3>Edit event</h3>
          <p>Update event details.</p>
        </div>
        <button className="ghost" onClick={onCancel}>Close</button>
      </div>
      {error && <div className="alert">{error}</div>}
      <form className="card-form card-form--wide" onSubmit={handleSubmit}>
        <input className="input" placeholder="Event title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <select className="select" value={eventType} onChange={(e) => setEventType(e.target.value)}>
          <option value="physical">Physical</option>
          <option value="virtual">Virtual</option>
          <option value="fair">Fair</option>
          <option value="workshop">Workshop</option>
        </select>
        <input className="input" type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} />
        {(eventType === 'physical' || eventType === 'fair' || eventType === 'workshop') && (
          <input
            className="input"
            placeholder="Location"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
          />
        )}
        {(eventType === 'virtual' || eventType === 'fair' || eventType === 'workshop') && (
          <input
            className="input"
            placeholder="Meeting URL"
            value={meetingUrl}
            onChange={(e) => setMeetingUrl(e.target.value)}
          />
        )}
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Saving...' : 'Save'}
        </button>
      </form>
    </div>
  );
}

function EventsView({ institutionId, refreshKey, allowHardDelete, currentUser }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState(null);
  const [confirmState, setConfirmState] = useState({ open: false });
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [guardState, setGuardState] = useState({ open: false });
  const [myOnly, setMyOnly] = useState(false);
  const [typeFilter, setTypeFilter] = useState('All');

  const loadData = async () => {
    if (!institutionId) return;
    setLoading(true);
    fetchEvents(institutionId, { page, perPage: 15 })
      .then((res) => {
        setRows(res?.data || []);
        setMeta(res?.meta || null);
      })
      .catch((err) => setError(err.message || 'Failed to load events'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [institutionId, page, refreshKey]);

  useEffect(() => {
    setSelectedIds(new Set());
  }, [page, refreshKey]);

  if (!institutionId) {
    return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;
  }

  function confirmDeactivate(id) {
    setConfirmState({
      open: true,
      title: 'Deactivate event',
      message: 'This event will no longer be visible to users. You can re-create it later if needed.',
      confirmLabel: 'Deactivate',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await deactivateEvent(id);
          setRows((prev) => prev.filter((r) => r.id !== id));
        } catch (err) {
          setError(err.message || 'Failed to deactivate event');
        }
      },
    });
  }

  function confirmPurge(id) {
    setConfirmState({
      open: true,
      title: 'Delete event permanently',
      message: 'This will permanently delete the event and cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await purgeEvent(id);
          setRows((prev) => prev.filter((r) => r.id !== id));
        } catch (err) {
          setError(err.message || 'Failed to delete event');
        }
      },
    });
  }

  function toggleSelection(id) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    setSelectedIds((prev) => {
      if (prev.size === rows.length) return new Set();
      return new Set(rows.map((r) => r.id));
    });
  }

  function confirmBulkDelete() {
    if (!selectedIds.size) return;
    setGuardState({
      open: true,
      title: 'Bulk delete events',
      message: `This will permanently delete ${selectedIds.size} events. This action cannot be undone.`,
      confirmLabel: 'Delete',
    });
  }

  async function handleBulkDelete() {
    const ids = Array.from(selectedIds);
    setGuardState({ open: false });
    try {
      await Promise.all(ids.map((id) => purgeEvent(id)));
      setRows((prev) => prev.filter((r) => !selectedIds.has(r.id)));
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Failed to delete events');
    }
  }

  function exportCsv() {
    if (!rows.length) return;
    const headers = ['id', 'title', 'type', 'starts_at', 'going_count'];
    const lines = rows.map((row) => {
      return [row.id, row.title, row.event_type, row.starts_at || '', row.going_count ?? 0]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'events.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  if (!institutionId) return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;

  const filteredRows = rows.filter((row) => {
    if (myOnly && currentUser?.id && row.creator?.id !== currentUser.id) return false;
    if (typeFilter !== 'All' && (row.event_type || '').toLowerCase() !== typeFilter.toLowerCase()) return false;
    return true;
  });

  const availableTypes = useMemo(() => {
    const types = new Set(rows.map((row) => (row.event_type || '').toString()).filter((v) => v));
    return ['All', ...Array.from(types)];
  }, [rows]);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Events</h2>
          <p>Manage institution events.</p>
        </div>
        <div className="panel-actions">
          <button className="ghost" onClick={exportCsv} disabled={!rows.length}>Export CSV</button>
        </div>
      </div>
      {editing && (
        <EditEventCard
          event={editing}
          onSaved={() => {
            setEditing(null);
            loadData();
          }}
          onCancel={() => setEditing(null)}
        />
      )}
      {allowHardDelete && selectedIds.size > 0 && (
        <div className="bulk-actions">
          <div className="bulk-count">{selectedIds.size} selected</div>
          <button className="ghost danger" onClick={confirmBulkDelete}>Bulk delete</button>
        </div>
      )}
      {error && <div className="alert">{error}</div>}
      {currentUser?.id && (
        <div className="filter-chips">
          <button className={`filter-chip${!myOnly ? ' active' : ''}`} onClick={() => setMyOnly(false)}>
            All events
          </button>
          <button className={`filter-chip${myOnly ? ' active' : ''}`} onClick={() => setMyOnly(true)}>
            My events
          </button>
        </div>
      )}
      {availableTypes.length > 1 && (
        <div className="filter-chips">
          {availableTypes.map((type) => (
            <button
              key={type}
              className={`filter-chip${typeFilter === type ? ' active' : ''}`}
              onClick={() => setTypeFilter(type)}
            >
              {type === 'All' ? 'All types' : type}
            </button>
          ))}
        </div>
      )}
      <div className={`table ${allowHardDelete ? 'table--selectable' : ''}`}>
        <div className="table-row table-row--head">
          {allowHardDelete && (
            <div>
              <input
                type="checkbox"
                checked={rows.length > 0 && selectedIds.size === rows.length}
                onChange={toggleAll}
              />
            </div>
          )}
          <div>Title</div>
          <div>Type</div>
          <div>Starts</div>
          <div>Going</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No events found.</div></div>
        ) : (
          filteredRows.map((row) => (
            <div className="table-row" key={row.id}>
              {allowHardDelete && (
                <div>
                  <input
                    type="checkbox"
                    checked={selectedIds.has(row.id)}
                    onChange={() => toggleSelection(row.id)}
                  />
                </div>
              )}
              <div>{row.title}</div>
              <div><span className="badge">{row.event_type || 'event'}</span></div>
              <div>{row.starts_at ? new Date(row.starts_at).toLocaleString() : '-'}</div>
              <div>{row.going_count ?? 0}</div>
              <div className="actions">
                <button className="ghost" onClick={() => setEditing(row)}>Edit</button>
                <button className="ghost" onClick={() => confirmDeactivate(row.id)}>Deactivate</button>
                {allowHardDelete && (
                  <button className="ghost danger" onClick={() => confirmPurge(row.id)}>Delete</button>
                )}
              </div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
      <GuardedModal
        open={guardState.open}
        title={guardState.title}
        message={guardState.message}
        confirmLabel={guardState.confirmLabel}
        guardText="DELETE"
        onCancel={() => setGuardState({ open: false })}
        onConfirm={handleBulkDelete}
      />
    </div>
  );
}

function CreateDonationCard({ institutionId, onCreated }) {
  const [title, setTitle] = useState('');
  const [target, setTarget] = useState('');
  const [currency, setCurrency] = useState('GHS');
  const [description, setDescription] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [status, setStatus] = useState('active');
  const [uploadingImage, setUploadingImage] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const MAX_UPLOAD_SIZE = 2 * 1024 * 1024;
  const ALLOWED_TYPES = ['image/png', 'image/jpeg'];

  async function handleImageUpload(file) {
    if (!file) return;
    if (!ALLOWED_TYPES.includes(file.type)) {
      setError('Only PNG or JPG images are allowed.');
      return;
    }
    if (file.size > MAX_UPLOAD_SIZE) {
      setError('File is too large. Max size is 2MB.');
      return;
    }
    setUploadingImage(true);
    try {
      const data = await uploadAdminMedia(file);
      if (data?.url) setImageUrl(data.url);
    } catch (err) {
      setError(err.message || 'Upload failed');
    } finally {
      setUploadingImage(false);
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim() || !target) return;
    setLoading(true);
    setError('');
    try {
      await createDonationCampaign({
        title: title.trim(),
        target_amount: Number(target),
        currency: currency.trim().toUpperCase(),
        description: description.trim() || null,
        image_url: imageUrl || null,
        is_active: status === 'active',
        institution_id: institutionId || undefined,
      });
      setTitle('');
      setTarget('');
      setCurrency('GHS');
      setDescription('');
      setImageUrl('');
      setStatus('active');
      onCreated?.();
    } catch (err) {
      setError(err.message || 'Failed to create campaign');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Create donation campaign</h3>
      <p>Launch fundraising campaigns for alumni support.</p>
      {error && <div className="alert">{error}</div>}
      <form className="card-form two-col" onSubmit={handleSubmit}>
        <div className="form-section">Campaign basics</div>
        <input className="input" placeholder="Campaign title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <input className="input" placeholder="Target amount" type="number" value={target} onChange={(e) => setTarget(e.target.value)} />
        <select className="select" value={currency} onChange={(e) => setCurrency(e.target.value)}>
          <option value="GHS">GHS</option>
          <option value="USD">USD</option>
          <option value="GBP">GBP</option>
          <option value="EUR">EUR</option>
        </select>
        <div className="file-row">
          <input className="input" placeholder="Cover image" value={imageUrl} readOnly />
          <div className="upload-thumb">
            {imageUrl ? <img src={resolveMediaUrl(imageUrl)} alt="Cover preview" /> : 'Cover'}
          </div>
          <label className="file-upload">
            <input
              type="file"
              accept="image/png,image/jpeg"
              onChange={(e) => {
                const file = e.target.files?.[0];
                e.target.value = '';
                handleImageUpload(file);
              }}
            />
            {uploadingImage ? 'Uploading...' : 'Upload cover'}
          </label>
        </div>
        <textarea
          className="input"
          rows="3"
          placeholder="About donation project"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <div className="form-divider" />
        <div className="form-section">Publish</div>
        <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="active">Publish now</option>
          <option value="inactive">Save as draft</option>
        </select>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create'}
        </button>
      </form>
    </div>
  );
}

function EditDonationCard({ campaign, onSaved, onCancel }) {
  const [title, setTitle] = useState(campaign?.title || '');
  const [target, setTarget] = useState(campaign?.target_amount || '');
  const [currency, setCurrency] = useState(campaign?.currency || 'GHS');
  const [description, setDescription] = useState(campaign?.description || '');
  const [imageUrl, setImageUrl] = useState(campaign?.image_url || '');
  const [status, setStatus] = useState(campaign?.is_active ? 'active' : 'inactive');
  const [uploadingImage, setUploadingImage] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const MAX_UPLOAD_SIZE = 2 * 1024 * 1024;
  const ALLOWED_TYPES = ['image/png', 'image/jpeg'];

  async function handleImageUpload(file) {
    if (!file) return;
    if (!ALLOWED_TYPES.includes(file.type)) {
      setError('Only PNG or JPG images are allowed.');
      return;
    }
    if (file.size > MAX_UPLOAD_SIZE) {
      setError('File is too large. Max size is 2MB.');
      return;
    }
    setUploadingImage(true);
    try {
      const data = await uploadAdminMedia(file);
      if (data?.url) setImageUrl(data.url);
    } catch (err) {
      setError(err.message || 'Upload failed');
    } finally {
      setUploadingImage(false);
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim() || !target) return;
    setLoading(true);
    setError('');
    try {
      await updateDonationCampaign(campaign.id, {
        title: title.trim(),
        target_amount: Number(target),
        currency: currency.trim().toUpperCase(),
        description: description.trim() || null,
        image_url: imageUrl || null,
        is_active: status === 'active',
      });
      onSaved?.();
    } catch (err) {
      setError(err.message || 'Failed to update campaign');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <div className="card-title-row">
        <div>
          <h3>Edit donation campaign</h3>
          <p>Update campaign details.</p>
        </div>
        <button className="ghost" onClick={onCancel}>Close</button>
      </div>
      {error && <div className="alert">{error}</div>}
      <form className="card-form two-col" onSubmit={handleSubmit}>
        <div className="form-section">Campaign basics</div>
        <input className="input" placeholder="Campaign title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <input className="input" placeholder="Target amount" type="number" value={target} onChange={(e) => setTarget(e.target.value)} />
        <select className="select" value={currency} onChange={(e) => setCurrency(e.target.value)}>
          <option value="GHS">GHS</option>
          <option value="USD">USD</option>
          <option value="GBP">GBP</option>
          <option value="EUR">EUR</option>
        </select>
        <div className="file-row">
          <input className="input" placeholder="Cover image" value={imageUrl} readOnly />
          <div className="upload-thumb">
            {imageUrl ? <img src={resolveMediaUrl(imageUrl)} alt="Cover preview" /> : 'Cover'}
          </div>
          <label className="file-upload">
            <input
              type="file"
              accept="image/png,image/jpeg"
              onChange={(e) => {
                const file = e.target.files?.[0];
                e.target.value = '';
                handleImageUpload(file);
              }}
            />
            {uploadingImage ? 'Uploading...' : 'Upload cover'}
          </label>
        </div>
        <textarea
          className="input"
          rows="3"
          placeholder="About donation project"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <div className="form-divider" />
        <div className="form-section">Update</div>
        <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="active">Publish now</option>
          <option value="inactive">Save as draft</option>
        </select>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Saving...' : 'Save'}
        </button>
      </form>
    </div>
  );
}

function DonationReportModal({
  open,
  report,
  onClose,
  onExportDonors,
  onPageChange,
  pageMeta,
  page,
}) {
  if (!open || !report) return null;
  const campaign = report.campaign;
  const stats = report.stats || {};
  const donations = report.donations || [];

  function exportDonorTemplate() {
    const headers = ['donor_name', 'donor_email', 'amount', 'currency', 'message', 'is_anonymous'];
  const sample = ['Jane Alumni', 'jane@example.com', '100', campaign?.currency || 'GHS', 'Proud to support', 'false'];
    const csv = [headers.join(','), sample.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'donation-donors-template.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  function exportSummaryCsv() {
    const headers = [
      'campaign_id',
      'title',
      'currency',
      'total_donations',
      'total_raised',
      'average_donation',
      'top_donation',
      'platform_fee_percent',
      'platform_fee_total',
      'net_raised',
    ];
    const feeTotal = Number(stats.platform_fee_total ?? 0);
    const totalRaised = Number(stats.total_raised ?? 0);
    const netRaised = totalRaised - feeTotal;
    const row = [
      campaign?.id || '',
      campaign?.title || '',
      campaign?.currency || '',
      stats.total_donations ?? 0,
      stats.total_raised ?? 0,
      stats.average_donation ?? 0,
      stats.top_donation ?? 0,
      stats.platform_fee_percent ?? 0,
      stats.platform_fee_total ?? 0,
      netRaised,
    ];
    const csv = [headers.join(','), row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `donation-report-${campaign?.id || 'campaign'}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-title">Campaign report</div>
        <div className="modal-message">{campaign?.title || 'Donation campaign'}</div>
        {campaign?.image_url ? (
          <div style={{ marginBottom: '12px' }}>
            <img
              src={resolveMediaUrl(campaign.image_url)}
              alt="Campaign cover"
              style={{ width: '100%', borderRadius: '12px', maxHeight: '180px', objectFit: 'cover' }}
            />
          </div>
        ) : null}
        {campaign?.description ? (
          <div className="alert success" style={{ marginBottom: '12px' }}>
            About donation project: {campaign.description}
          </div>
        ) : null}
        <div className="card-form">
          <div>Total donations: {stats.total_donations ?? 0}</div>
          <div>Total raised: {formatCurrency(campaign?.currency || 'GHS', stats.total_raised ?? 0)}</div>
          <div>Platform fee: {stats.platform_fee_percent ?? 0}%</div>
          <div>Platform fee total: {formatCurrency(campaign?.currency || 'GHS', stats.platform_fee_total ?? 0)}</div>
          <div>Net raised: {formatCurrency(campaign?.currency || 'GHS', (Number(stats.total_raised ?? 0) - Number(stats.platform_fee_total ?? 0)))}</div>
          <div>Average donation: {formatCurrency(campaign?.currency || 'GHS', stats.average_donation ?? 0)}</div>
          <div>Top donation: {formatCurrency(campaign?.currency || 'GHS', stats.top_donation ?? 0)}</div>
        </div>
        <div className="table">
          <div className="table-row table-row--head">
            <div>Donor</div>
            <div>Email</div>
            <div>Amount</div>
            <div>Date</div>
          </div>
          {donations.length === 0 ? (
            <div className="table-row"><div>No donations found.</div></div>
          ) : (
            donations.map((row) => (
              <div className="table-row" key={row.id}>
                <div>{row.user?.name || 'Anonymous'}</div>
                <div>{row.user?.email || '-'}</div>
                <div>{formatCurrency(row.currency, row.amount)}</div>
                <div>{row.created_at ? new Date(row.created_at).toLocaleDateString() : '-'}</div>
              </div>
            ))
          )}
        </div>
        {pageMeta && (
          <div className="pagination">
            <button className="ghost" onClick={() => onPageChange?.(page - 1)} disabled={page <= 1}>Prev</button>
            <span>Page {page}</span>
            <button className="ghost" onClick={() => onPageChange?.(page + 1)} disabled={pageMeta && page >= (pageMeta?.last_page || page)}>Next</button>
          </div>
        )}
        <div className="modal-actions">
          <button className="ghost" onClick={exportSummaryCsv}>Export summary CSV</button>
          <button className="ghost" onClick={exportDonorTemplate}>Download donors template</button>
          <button className="ghost" onClick={onExportDonors}>Export donors CSV</button>
          <button className="primary" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}

function DonationsView({ institutionId, refreshKey, allowHardDelete }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState(null);
  const [confirmState, setConfirmState] = useState({ open: false });
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [guardState, setGuardState] = useState({ open: false });
  const [report, setReport] = useState(null);
  const [quickFilter, setQuickFilter] = useState('all');
  const [archivedOnly, setArchivedOnly] = useState(false);
  const [openMenuId, setOpenMenuId] = useState(null);
  const summary = useMemo(() => {
    const total = rows.length;
    const active = rows.filter((row) => row.is_active).length;
    const raised = rows.reduce((sum, row) => sum + (Number(row.raised_amount) || 0), 0);
    const currencies = Array.from(new Set(rows.map((row) => row.currency).filter(Boolean)));
    const currencyLabel = currencies.length === 1 ? currencySymbol(currencies[0]) : currencies.length > 1 ? 'Multi' : '';
    return { total, active, raised, currencyLabel };
  }, [rows]);
  const filteredRows = useMemo(() => {
    let base = rows;
    if (archivedOnly) {
      base = base.filter((row) => !row.is_active);
    }
    if (quickFilter === 'high') {
      return base.filter((row) => {
        const target = Number(row.target_amount) || 0;
        const raised = Number(row.raised_amount) || 0;
        if (!target) return false;
        return raised / target >= 0.8;
      });
    }
    if (quickFilter === 'active') return base.filter((row) => row.is_active);
    if (quickFilter === 'inactive') return base.filter((row) => !row.is_active);
    return base;
  }, [rows, quickFilter, archivedOnly]);

  const loadData = async () => {
    if (!institutionId) return;
    setLoading(true);
    fetchDonations(institutionId, { page, perPage: 15 })
      .then((res) => {
        setRows(res?.data || []);
        setMeta(res?.meta || null);
      })
      .catch((err) => setError(err.message || 'Failed to load campaigns'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [institutionId, page, refreshKey]);

  useEffect(() => {
    setSelectedIds(new Set());
  }, [page, refreshKey]);

  if (!institutionId) {
    return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;
  }

  function confirmDeactivate(id) {
    setConfirmState({
      open: true,
      title: 'Deactivate campaign',
      message: 'This campaign will no longer be visible to donors.',
      confirmLabel: 'Deactivate',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await deactivateDonationCampaign(id);
          setRows((prev) => prev.filter((r) => r.id !== id));
        } catch (err) {
          setError(err.message || 'Failed to deactivate campaign');
        }
      },
    });
  }

  function confirmPurge(id) {
    setConfirmState({
      open: true,
      title: 'Delete campaign permanently',
      message: 'This will permanently delete the campaign and cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await purgeDonationCampaign(id);
          setRows((prev) => prev.filter((r) => r.id !== id));
        } catch (err) {
          setError(err.message || 'Failed to delete campaign');
        }
      },
    });
  }

  async function openReport(campaign) {
    try {
      const data = await fetchDonationCampaignReport(campaign.id);
      let donationRows = [];
      let donationMeta = null;
      try {
        const donations = await fetchDonationCampaignDonations(campaign.id, { page: 1, perPage: 10 });
        donationRows = donations?.data || [];
        donationMeta = donations?.meta || null;
      } catch (_) {
        donationRows = [];
      }
      setReport({
        ...data,
        campaignId: campaign.id,
        donations: donationRows,
        donationsMeta: donationMeta,
        donationsPage: 1,
      });
    } catch (err) {
      setError(err.message || 'Failed to load report');
    }
  }

  async function changeReportPage(nextPage) {
    if (!report?.campaignId || nextPage < 1) return;
    try {
      const donations = await fetchDonationCampaignDonations(report.campaignId, { page: nextPage, perPage: 10 });
      setReport((prev) => ({
        ...prev,
        donations: donations?.data || [],
        donationsMeta: donations?.meta || null,
        donationsPage: nextPage,
      }));
    } catch (err) {
      setError(err.message || 'Failed to load donations');
    }
  }

  async function exportDonorsCsv() {
    if (!report?.campaignId) return;
    try {
      const allRows = [];
      let page = 1;
      let lastPage = 1;
      do {
        const data = await fetchDonationCampaignDonations(report.campaignId, { page, perPage: 50 });
        const batch = data?.data || [];
        allRows.push(...batch);
        lastPage = data?.meta?.last_page || page;
        page += 1;
      } while (page <= lastPage);

      if (!allRows.length) return;
      const headers = ['id', 'donor_name', 'donor_email', 'amount', 'currency', 'status', 'created_at'];
      const lines = allRows.map((row) => {
        const donor = row.user || {};
        return [
          row.id,
          donor.name || 'Anonymous',
          donor.email || '',
          row.amount,
          row.currency,
          row.status,
          row.created_at,
        ]
          .map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`)
          .join(',');
      });
      const csv = [headers.join(','), ...lines].join('\n');
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `donors-${report.campaignId}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      setError(err.message || 'Failed to export donors');
    }
  }

  function toggleSelection(id) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  useEffect(() => {
    function handleClick() {
      setOpenMenuId(null);
    }
    if (openMenuId == null) return () => {};
    document.addEventListener('click', handleClick);
    return () => document.removeEventListener('click', handleClick);
  }, [openMenuId]);

  function toggleAll() {
    setSelectedIds((prev) => {
      if (prev.size === rows.length) return new Set();
      return new Set(rows.map((r) => r.id));
    });
  }

  function confirmBulkDelete() {
    if (!selectedIds.size) return;
    setGuardState({
      open: true,
      title: 'Bulk delete campaigns',
      message: `This will permanently delete ${selectedIds.size} campaigns. This action cannot be undone.`,
      confirmLabel: 'Delete',
    });
  }

  async function handleBulkDelete() {
    const ids = Array.from(selectedIds);
    setGuardState({ open: false });
    try {
      await Promise.all(ids.map((id) => purgeDonationCampaign(id)));
      setRows((prev) => prev.filter((r) => !selectedIds.has(r.id)));
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Failed to delete campaigns');
    }
  }

  function exportCsv() {
    if (!rows.length) return;
    const headers = ['id', 'title', 'target_amount', 'raised_amount', 'currency', 'status'];
    const lines = rows.map((row) => {
      return [row.id, row.title, row.target_amount, row.raised_amount, row.currency, row.is_active ? 'active' : 'inactive']
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'donation-campaigns.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  function toggleMenu(id) {
    setOpenMenuId((prev) => (prev === id ? null : id));
  }

  if (!institutionId) return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Donation campaigns</h2>
          <p>Track active and past campaigns.</p>
        </div>
        <div className="panel-actions">
          <button className="ghost" onClick={exportCsv} disabled={!rows.length}>Export CSV</button>
        </div>
      </div>
      {editing && (
        <EditDonationCard
          campaign={editing}
          onSaved={() => {
            setEditing(null);
            loadData();
          }}
          onCancel={() => setEditing(null)}
        />
      )}
      {allowHardDelete && selectedIds.size > 0 && (
        <div className="bulk-actions">
          <div className="bulk-count">{selectedIds.size} selected</div>
          <button className="ghost danger" onClick={confirmBulkDelete}>Bulk delete</button>
        </div>
      )}
      {error && <div className="alert">{error}</div>}
      <div className="filter-chips">
        {[
          { key: 'all', label: 'All campaigns' },
          { key: 'active', label: 'Active' },
          { key: 'inactive', label: 'Inactive' },
          { key: 'high', label: '80%+ funded' },
        ].map((chip) => (
          <button
            key={chip.key}
            className={`filter-chip${quickFilter === chip.key ? ' active' : ''}`}
            onClick={() => setQuickFilter(chip.key)}
          >
            {chip.label}
          </button>
        ))}
        <button
          className={`filter-chip${archivedOnly ? ' active' : ''}`}
          onClick={() => setArchivedOnly((prev) => !prev)}
        >
          Archived only
        </button>
      </div>
      <div className="metrics-grid reports-metrics">
        <div className="metric">
          <div className="metric-title">Campaigns (this page)</div>
          <div className="metric-value">{summary.total}</div>
          <div className="metric-subtitle">Total campaigns shown</div>
        </div>
        <div className="metric">
          <div className="metric-title">Active</div>
          <div className="metric-value">{summary.active}</div>
          <div className="metric-subtitle">Currently fundraising</div>
        </div>
        <div className="metric">
          <div className="metric-title">Raised (this page)</div>
          <div className="metric-value">
            {summary.currencyLabel ? `${summary.currencyLabel} ` : ''}
            {summary.raised.toFixed(2)}
          </div>
          <div className="metric-subtitle">Sum of raised amounts</div>
        </div>
      </div>
      <div className={`table table--donations ${allowHardDelete ? 'table--selectable' : ''}`}>
        <div className="table-row table-row--head">
          {allowHardDelete && (
            <div>
              <input
                type="checkbox"
                checked={rows.length > 0 && selectedIds.size === rows.length}
                onChange={toggleAll}
              />
            </div>
          )}
          <div>Cover</div>
          <div>Title</div>
          <div>Target</div>
          <div>Raised</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No campaigns found.</div></div>
        ) : (
          filteredRows.map((row) => (
            <div className="table-row" key={row.id}>
              {allowHardDelete && (
                <div>
                  <input
                    type="checkbox"
                    checked={selectedIds.has(row.id)}
                    onChange={() => toggleSelection(row.id)}
                  />
                </div>
              )}
              <div>
                <div className="upload-thumb">
                  {row.image_url ? <img src={resolveMediaUrl(row.image_url)} alt="Cover" /> : 'Cover'}
                </div>
              </div>
              <div className="title-cell">
                <strong>{row.title}</strong>
                <span>
                  {row.created_at ? new Date(row.created_at).toLocaleDateString() : 'Campaign'}
                  {(Number(row.raised_amount) || 0) >= (Number(row.target_amount) || 0) && Number(row.target_amount) > 0 ? ' • Goal met' : ''}
                  {row.description ? ` • ${String(row.description).slice(0, 80)}${String(row.description).length > 80 ? '…' : ''}` : ''}
                </span>
              </div>
              <div>
                {formatCurrency(row.currency, row.target_amount)}
              </div>
              <div>
                <div>{formatCurrency(row.currency, row.raised_amount)}</div>
                <div className="progress">
                  <div
                    className="progress-fill"
                    style={{
                      width: `${Math.min(100, (Number(row.raised_amount) || 0) / (Number(row.target_amount) || 1) * 100)}%`,
                    }}
                  />
                </div>
                <div
                  className={`badge${(Number(row.raised_amount) || 0) >= (Number(row.target_amount) || 0) ? ' goal' : ''}`}
                >
                  {Math.min(100, Math.round((Number(row.raised_amount) || 0) / (Number(row.target_amount) || 1) * 100))}%
                  {(Number(row.raised_amount) || 0) >= (Number(row.target_amount) || 0) ? ' • Goal reached' : ''}
                </div>
              </div>
              <div><StatusPill status={row.is_active ? 'active' : 'inactive'} /></div>
              <div className="actions">
                <div className="action-menu">
                  <button
                    className="ghost"
                    onClick={(e) => {
                      e.stopPropagation();
                      toggleMenu(row.id);
                    }}
                  >
                    Manage
                  </button>
                  {openMenuId === row.id && (
                    <div className="action-menu-list" onClick={(e) => e.stopPropagation()}>
                      <button className="ghost" onClick={() => { openReport(row); setOpenMenuId(null); }}>
                        [i] View details
                      </button>
                      <button className="ghost" onClick={() => { setEditing(row); setOpenMenuId(null); }}>
                        [e] Edit campaign
                      </button>
                      <button className="ghost" onClick={() => { confirmDeactivate(row.id); setOpenMenuId(null); }}>
                        {row.is_active ? 'Deactivate' : 'Activate'}
                      </button>
                      {allowHardDelete && (
                        <button className="ghost danger" onClick={() => { confirmPurge(row.id); setOpenMenuId(null); }}>
                          [x] Delete
                        </button>
                      )}
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
      <GuardedModal
        open={guardState.open}
        title={guardState.title}
        message={guardState.message}
        confirmLabel={guardState.confirmLabel}
        guardText="DELETE"
        onCancel={() => setGuardState({ open: false })}
        onConfirm={handleBulkDelete}
      />
      <DonationReportModal
        open={!!report}
        report={report}
        onClose={() => setReport(null)}
        onExportDonors={exportDonorsCsv}
        onPageChange={changeReportPage}
        pageMeta={report?.donationsMeta}
        page={report?.donationsPage || 1}
      />
    </div>
  );
}

function CreateAnnouncementCard({ institutionId, institutions, onCreated }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState(institutionId ? 'institution' : 'global');
  const [startsAt, setStartsAt] = useState('');
  const [endsAt, setEndsAt] = useState('');
  const [sendEmail, setSendEmail] = useState(false);
  const [isActive, setIsActive] = useState(true);
  const [selectedInstitution, setSelectedInstitution] = useState(institutionId || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (institutionId) {
      setAudience('institution');
      setSelectedInstitution(institutionId);
    }
  }, [institutionId]);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim() || !body.trim()) return;
    setLoading(true);
    setError('');
    try {
      await createAnnouncement({
        title: title.trim(),
        body: body.trim(),
        audience,
        institution_id: audience === 'institution' ? (selectedInstitution || null) : null,
        starts_at: startsAt || null,
        ends_at: endsAt || null,
        send_email: sendEmail,
        is_active: isActive,
      });
      setTitle('');
      setBody('');
      setStartsAt('');
      setEndsAt('');
      setSendEmail(false);
      setIsActive(true);
      onCreated?.();
    } catch (err) {
      setError(err.message || 'Failed to create announcement');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Create announcement</h3>
      <p>Broadcast important updates to alumni.</p>
      {error && <div className="alert">{error}</div>}
      <form className="card-form card-form--wide" onSubmit={handleSubmit}>
        <input className="input" placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <textarea className="input" rows="3" placeholder="Announcement body" value={body} onChange={(e) => setBody(e.target.value)} />
        <select className="select" value={audience} onChange={(e) => setAudience(e.target.value)}>
          <option value="global">Global</option>
          <option value="institution">Institution</option>
        </select>
        {audience === 'institution' && institutions?.length > 0 && (
          <select className="select" value={selectedInstitution} onChange={(e) => setSelectedInstitution(e.target.value)}>
            <option value="">Select institution</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <input className="input" type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} />
        <input className="input" type="datetime-local" value={endsAt} onChange={(e) => setEndsAt(e.target.value)} />
        <label className="checkbox">
          <input type="checkbox" checked={sendEmail} onChange={(e) => setSendEmail(e.target.checked)} />
          Send email blast
        </label>
        <label className="checkbox">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
          Publish now
        </label>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Publishing...' : 'Publish'}
        </button>
      </form>
    </div>
  );
}

function AnnouncementsView({ institutionId, institutions, scopeLabel }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [filters, setFilters] = useState({ audience: '', active: '' });
  const [editing, setEditing] = useState(null);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchAnnouncements({
        audience: filters.audience || undefined,
        active: filters.active === '' ? undefined : filters.active,
        institutionId,
        page,
        perPage: 20,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load announcements');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [page, institutionId, filters.audience, filters.active]);

  async function toggleActive(announcement) {
    try {
      const next = !announcement.is_active;
      await updateAnnouncement(announcement.id, { is_active: next });
      setRows((prev) => prev.map((row) => (row.id === announcement.id ? { ...row, is_active: next } : row)));
    } catch (err) {
      setError(err.message || 'Failed to update announcement');
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Announcements</h2>
          <p>Publish updates to alumni and institutions.</p>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      {editing ? (
        <div className="card">
          <div className="card-title-row">
            <div>
              <h3>Edit announcement</h3>
              <p>Update title, body, and schedule.</p>
            </div>
            <button className="ghost" onClick={() => setEditing(null)}>Close</button>
          </div>
          <form
            className="card-form card-form--wide"
            onSubmit={async (e) => {
              e.preventDefault();
              try {
                await updateAnnouncement(editing.id, {
                  title: editing.title,
                  body: editing.body,
                  starts_at: editing.starts_at || null,
                  ends_at: editing.ends_at || null,
                });
                setEditing(null);
                loadData();
              } catch (err) {
                setError(err.message || 'Failed to update announcement');
              }
            }}
          >
            <input className="input" value={editing.title} onChange={(e) => setEditing({ ...editing, title: e.target.value })} />
            <textarea className="input" rows="3" value={editing.body} onChange={(e) => setEditing({ ...editing, body: e.target.value })} />
            <input className="input" type="datetime-local" value={editing.starts_at || ''} onChange={(e) => setEditing({ ...editing, starts_at: e.target.value })} />
            <input className="input" type="datetime-local" value={editing.ends_at || ''} onChange={(e) => setEditing({ ...editing, ends_at: e.target.value })} />
            <button className="primary" type="submit">Save</button>
          </form>
        </div>
      ) : (
        <CreateAnnouncementCard institutionId={institutionId} institutions={institutions} onCreated={loadData} />
      )}
      <div className="card-form">
        <select className="select" value={filters.audience} onChange={(e) => setFilters({ ...filters, audience: e.target.value })}>
          <option value="">All audiences</option>
          <option value="global">Global</option>
          <option value="institution">Institution</option>
        </select>
        <select className="select" value={filters.active} onChange={(e) => setFilters({ ...filters, active: e.target.value })}>
          <option value="">All statuses</option>
          <option value="true">Active</option>
          <option value="false">Inactive</option>
        </select>
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="table table--wide support-table-section support-table--head-centered">
        <div className="table-row table-row--head">
          <div>Title</div>
          <div>Audience</div>
          <div>Institution</div>
          <div>Email</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No announcements found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div>{row.title}</div>
              <div>{row.audience}</div>
              <div>{row.institution?.name || '-'}</div>
            <div>{row.send_email ? 'Sent' : 'No'}</div>
            <div><StatusPill status={row.is_active ? 'active' : 'inactive'} /></div>
            <div className="actions">
              <button className="ghost" onClick={() => setEditing(row)}>Edit</button>
              <button className="ghost" onClick={() => toggleActive(row)}>
                {row.is_active ? 'Deactivate' : 'Activate'}
              </button>
              {!row.email_dispatched_at && (
                <button className="ghost" onClick={() => sendAnnouncementEmail(row.id).then(loadData)}>
                  Send email
                </button>
              )}
            </div>
          </div>
        ))
      )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
    </div>
  );
}

function CreateJobCard({ institutionId, institutions, onCreated }) {
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('');
  const [company, setCompany] = useState('');
  const [location, setLocation] = useState('');
  const [workMode, setWorkMode] = useState('');
  const [salary, setSalary] = useState('');
  const [experienceLevel, setExperienceLevel] = useState('');
  const [description, setDescription] = useState('');
  const [overview, setOverview] = useState('');
  const [status, setStatus] = useState('active');
  const [selectedInstitution, setSelectedInstitution] = useState(institutionId || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setSelectedInstitution(institutionId || '');
  }, [institutionId]);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim()) return;
    setLoading(true);
    setError('');
    try {
      await createJob({
        title: title.trim(),
        category: category || null,
        company_name: company || null,
        location: location || null,
        work_mode: workMode || null,
        salary: salary || null,
        experience_level: experienceLevel || null,
        overview: overview || null,
        description: description || null,
        is_active: status === 'active',
        institution_id: selectedInstitution || undefined,
      });
      setTitle('');
      setCategory('');
      setCompany('');
      setLocation('');
      setWorkMode('');
      setSalary('');
      setExperienceLevel('');
      setOverview('');
      setDescription('');
      setStatus('active');
      onCreated?.();
    } catch (err) {
      setError(err.message || 'Failed to create job');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Create job</h3>
      <p>Post new opportunities for alumni.</p>
      {error && <div className="alert">{error}</div>}
      <form className="card-form two-col" onSubmit={handleSubmit}>
        <div className="form-section">Job basics</div>
        <input className="input" placeholder="Job title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <input className="input" placeholder="Category" value={category} onChange={(e) => setCategory(e.target.value)} />
        <input className="input" placeholder="Company" value={company} onChange={(e) => setCompany(e.target.value)} />
        <div className="form-section">Location & compensation</div>
        <input className="input" placeholder="Location" value={location} onChange={(e) => setLocation(e.target.value)} />
        <select className="select" value={workMode} onChange={(e) => setWorkMode(e.target.value)}>
          <option value="">Work mode</option>
          <option value="remote">Remote</option>
          <option value="onsite">On-site</option>
          <option value="hybrid">Hybrid</option>
        </select>
        <input className="input" placeholder="Salary" value={salary} onChange={(e) => setSalary(e.target.value)} />
        <select className="select" value={experienceLevel} onChange={(e) => setExperienceLevel(e.target.value)}>
          <option value="">Experience level</option>
          <option value="entry">Entry</option>
          <option value="mid">Mid</option>
          <option value="senior">Senior</option>
          <option value="lead">Lead</option>
        </select>
        <textarea
          className="input"
          rows="3"
          placeholder="Overview"
          value={overview}
          onChange={(e) => setOverview(e.target.value)}
        />
        <textarea
          className="input"
          rows="4"
          placeholder="Job description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <div className="form-divider" />
        <div className="form-section">Publishing</div>
        {institutions?.length > 0 && (
          <select className="select" value={selectedInstitution} onChange={(e) => setSelectedInstitution(e.target.value)}>
            <option value="">No institution</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create'}
        </button>
      </form>
    </div>
  );
}

function ImportJobsCard({ institutionId, institutions, onImported }) {
  const [file, setFile] = useState(null);
  const [selectedInstitution, setSelectedInstitution] = useState(institutionId || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState(null);

  useEffect(() => {
    setSelectedInstitution(institutionId || '');
  }, [institutionId]);

  function downloadTemplate() {
    const headers = ['title', 'category', 'company_name', 'location', 'work_mode', 'salary', 'experience_level', 'overview', 'description', 'is_active', 'published_at'];
    const sample = [
      'Senior Developer',
      'Tech',
      'Verix Teams',
      'Remote',
      'remote',
      '100000',
      'senior',
      'Build scalable systems',
      'Full job description here',
      'true',
      new Date().toISOString().split('T')[0],
    ];
    const csv = [headers.join(','), sample.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'jobs-template.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  function downloadErrorReport() {
    if (!result?.errors?.length) return;
    const headers = ['row_number', 'error', 'row'];
    const lines = result.errors.map((err) => {
      const row = JSON.stringify(err.row || {});
      return [err.row_number || '', err.error || 'Error', row]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'jobs-import-errors.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!file) return;
    setLoading(true);
    setError('');
    setResult(null);
    try {
      const data = await importJobsCsv(file, selectedInstitution || undefined);
      setResult(data);
      onImported?.();
    } catch (err) {
      setError(err.message || 'Failed to import CSV');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Bulk import (CSV)</h3>
      <p>Upload a CSV with columns: title, category, company_name, location, work_mode, salary, experience_level, overview, description, is_active, published_at.</p>
      {error && <div className="alert">{error}</div>}
      {result && (
        <div className="alert">
          Imported: {result.created || 0}
          {result.errors && result.errors.length > 0 ? ` • Errors: ${result.errors.length}` : ''}
        </div>
      )}
      {result?.errors?.length > 0 && (
        <div className="table">
          <div className="table-row table-row--head">
            <div>Row</div>
            <div>Error</div>
            <div>Data</div>
          </div>
          {result.errors.slice(0, 5).map((err, idx) => (
            <div className="table-row" key={idx}>
              <div>{err.row_number || '-'}</div>
              <div>{err.error || 'Error'}</div>
              <div className="mono">{JSON.stringify(err.row || {})}</div>
            </div>
          ))}
        </div>
      )}
      <form className="card-form card-form--wide" onSubmit={handleSubmit}>
        <input
          type="file"
          accept=".csv"
          onChange={(e) => {
            const nextFile = e.target.files?.[0] || null;
            if (!nextFile) {
              setFile(null);
              return;
            }
            if (!nextFile.name.toLowerCase().endsWith('.csv')) {
              setError('Please upload a .csv file.');
              setFile(null);
              return;
            }
            if (nextFile.size > 5 * 1024 * 1024) {
              setError('CSV file must be under 5MB.');
              setFile(null);
              return;
            }
            setError('');
            setFile(nextFile);
          }}
        />
        {institutions?.length > 0 && (
          <select className="select" value={selectedInstitution} onChange={(e) => setSelectedInstitution(e.target.value)}>
            <option value="">No institution</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <button className="ghost" type="button" onClick={downloadTemplate}>
          Download template
        </button>
        <button className="primary" type="submit" disabled={loading || !file}>
          {loading ? 'Importing...' : 'Import'}
        </button>
        <button className="ghost" type="button" onClick={downloadErrorReport} disabled={!result?.errors?.length}>
          Download errors
        </button>
      </form>
    </div>
  );
}

function EditJobCard({ job, institutions, onSaved, onCancel }) {
  const [title, setTitle] = useState(job?.title || '');
  const [category, setCategory] = useState(job?.category || '');
  const [company, setCompany] = useState(job?.company_name || '');
  const [location, setLocation] = useState(job?.location || '');
  const [workMode, setWorkMode] = useState(job?.work_mode || '');
  const [salary, setSalary] = useState(job?.salary || '');
  const [experienceLevel, setExperienceLevel] = useState(job?.experience_level || '');
  const [description, setDescription] = useState(job?.description || '');
  const [overview, setOverview] = useState(job?.overview || '');
  const [status, setStatus] = useState(job?.is_active ? 'active' : 'inactive');
  const [selectedInstitution, setSelectedInstitution] = useState(job?.institution?.id || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setTitle(job?.title || '');
    setCategory(job?.category || '');
    setCompany(job?.company_name || '');
    setLocation(job?.location || '');
    setWorkMode(job?.work_mode || '');
    setSalary(job?.salary || '');
    setExperienceLevel(job?.experience_level || '');
    setDescription(job?.description || '');
    setOverview(job?.overview || '');
    setStatus(job?.is_active ? 'active' : 'inactive');
    setSelectedInstitution(job?.institution?.id || '');
  }, [job]);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim()) return;
    setLoading(true);
    setError('');
    try {
      await updateJob(job.id, {
        title: title.trim(),
        category: category || null,
        company_name: company || null,
        location: location || null,
        work_mode: workMode || null,
        salary: salary || null,
        experience_level: experienceLevel || null,
        overview: overview || null,
        description: description || null,
        is_active: status === 'active',
        institution_id: selectedInstitution || undefined,
      });
      onSaved?.();
    } catch (err) {
      setError(err.message || 'Failed to update job');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <div className="card-title-row">
        <div>
          <h3>Edit job</h3>
          <p>Update job details.</p>
        </div>
        <button className="ghost" onClick={onCancel}>Close</button>
      </div>
      {error && <div className="alert">{error}</div>}
      <form className="card-form two-col" onSubmit={handleSubmit}>
        <div className="form-section">Job basics</div>
        <input className="input" placeholder="Job title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <input className="input" placeholder="Category" value={category} onChange={(e) => setCategory(e.target.value)} />
        <input className="input" placeholder="Company" value={company} onChange={(e) => setCompany(e.target.value)} />
        <div className="form-section">Location & compensation</div>
        <input className="input" placeholder="Location" value={location} onChange={(e) => setLocation(e.target.value)} />
        <select className="select" value={workMode} onChange={(e) => setWorkMode(e.target.value)}>
          <option value="">Work mode</option>
          <option value="remote">Remote</option>
          <option value="onsite">On-site</option>
          <option value="hybrid">Hybrid</option>
        </select>
        <input className="input" placeholder="Salary" value={salary} onChange={(e) => setSalary(e.target.value)} />
        <select className="select" value={experienceLevel} onChange={(e) => setExperienceLevel(e.target.value)}>
          <option value="">Experience level</option>
          <option value="entry">Entry</option>
          <option value="mid">Mid</option>
          <option value="senior">Senior</option>
          <option value="lead">Lead</option>
        </select>
        <textarea
          className="input"
          rows="3"
          placeholder="Overview"
          value={overview}
          onChange={(e) => setOverview(e.target.value)}
        />
        <textarea
          className="input"
          rows="4"
          placeholder="Job description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <div className="form-divider" />
        <div className="form-section">Publishing</div>
        {institutions?.length > 0 && (
          <select className="select" value={selectedInstitution} onChange={(e) => setSelectedInstitution(e.target.value)}>
            <option value="">No institution</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Saving...' : 'Save'}
        </button>
      </form>
    </div>
  );
}

function JobsView({ institutionId, institutions, scopeLabel }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState(null);
  const [filters, setFilters] = useState({ status: '', q: '', category: '', salaryMin: '', salaryMax: '' });
  const [confirmState, setConfirmState] = useState({ open: false });
  const [institutionFilter, setInstitutionFilter] = useState('');
  const [analytics, setAnalytics] = useState([]);
  const [quickStatus, setQuickStatus] = useState('');
  const [openMenuId, setOpenMenuId] = useState(null);
  const [viewJob, setViewJob] = useState(null);
  const summary = useMemo(() => {
    const total = rows.length;
    const active = rows.filter((row) => row.is_active).length;
    const inactive = total - active;
    return { total, active, inactive };
  }, [rows]);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchJobsAdmin({
        ...filters,
        institutionId: institutionId || (institutionFilter ? Number(institutionFilter) : undefined),
        page,
        perPage: 20,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load jobs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [page, filters.status, filters.q, filters.category, filters.salaryMin, filters.salaryMax, institutionId, institutionFilter]);

  useEffect(() => {
    function handleClick(e) {
      const target = e.target;
      if (target instanceof Element) {
        if (target.closest('.action-menu') || target.closest('.table-row')) {
          return;
        }
      }
      setOpenMenuId(null);
    }
    if (openMenuId == null) return () => {};
    document.addEventListener('click', handleClick);
    return () => document.removeEventListener('click', handleClick);
  }, [openMenuId]);

  const filteredRows = useMemo(() => {
    return rows.filter((row) => {
      const salaryRaw = String(row.salary || '').replace(/[^0-9.]/g, '');
      const value = Number(salaryRaw);
      const min = Number(filters.salaryMin || '');
      const max = Number(filters.salaryMax || '');
      if (!Number.isNaN(min) && filters.salaryMin) {
        if (Number.isNaN(value) || value < min) return false;
      }
      if (!Number.isNaN(max) && filters.salaryMax) {
        if (Number.isNaN(value) || value > max) return false;
      }
      if (quickStatus === 'high') {
        return !Number.isNaN(value) && value >= 100000;
      }
      return true;
    });
  }, [rows, quickStatus, filters.salaryMin, filters.salaryMax]);

  useEffect(() => {
    fetchJobsAnalytics({ institutionId: institutionId || (institutionFilter ? Number(institutionFilter) : undefined) })
      .then((res) => setAnalytics(res?.data || []))
      .catch(() => setAnalytics([]));
  }, [institutionId, institutionFilter]);

  function confirmDelete(job) {
    setConfirmState({
      open: true,
      title: 'Delete job',
      message: `Delete "${job.title}"?`,
      confirmLabel: 'Delete',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await deleteJob(job.id);
          setRows((prev) => prev.filter((row) => row.id !== job.id));
        } catch (err) {
          setError(err.message || 'Failed to delete job');
        }
      },
    });
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Jobs</h2>
          <p>Manage job listings for alumni.</p>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      {editing ? (
        <EditJobCard
          job={editing}
          institutions={institutions}
          onSaved={() => {
            setEditing(null);
            loadData();
          }}
          onCancel={() => setEditing(null)}
        />
      ) : (
        <div className="stack">
          <CreateJobCard institutionId={institutionId} institutions={institutions} onCreated={loadData} />
          <ImportJobsCard institutionId={institutionId} institutions={institutions} onImported={loadData} />
        </div>
      )}
      {analytics.length > 0 && (
        <div className="card">
          <h3>Jobs by category</h3>
          <div className="table">
            <div className="table-row table-row--head">
              <div>Category</div>
              <div>Total</div>
            </div>
            {analytics.map((row) => (
              <div className="table-row" key={row.category}>
                <div>{row.category}</div>
                <div>{row.total}</div>
              </div>
            ))}
          </div>
        </div>
      )}
      <div className="metrics-grid reports-metrics">
        <div className="metric">
          <div className="metric-title">Jobs (this page)</div>
          <div className="metric-value">{summary.total}</div>
          <div className="metric-subtitle">Total listings shown</div>
        </div>
        <div className="metric">
          <div className="metric-title">Active</div>
          <div className="metric-value">{summary.active}</div>
          <div className="metric-subtitle">Currently live</div>
        </div>
        <div className="metric">
          <div className="metric-title">Inactive</div>
          <div className="metric-value">{summary.inactive}</div>
          <div className="metric-subtitle">Paused listings</div>
        </div>
      </div>
      <div className="filter-chips">
        {[
          { key: '', label: 'All jobs' },
          { key: 'active', label: 'Active' },
          { key: 'inactive', label: 'Inactive' },
          { key: 'high', label: 'High salary' },
        ].map((chip) => (
          <button
            key={chip.label}
            className={`filter-chip${(quickStatus || '') === chip.key ? ' active' : ''}`}
            onClick={() => {
              setQuickStatus(chip.key);
              if (chip.key !== 'high') {
                setFilters((prev) => ({ ...prev, status: chip.key }));
              }
            }}
          >
            {chip.label}
          </button>
        ))}
      </div>
      <div className="card-form">
        <input className="input" placeholder="Search jobs" value={filters.q} onChange={(e) => setFilters({ ...filters, q: e.target.value })} />
        <input className="input" placeholder="Category" value={filters.category} onChange={(e) => setFilters({ ...filters, category: e.target.value })} />
        <input
          className="input"
          placeholder="Min salary"
          value={filters.salaryMin}
          onChange={(e) => setFilters({ ...filters, salaryMin: e.target.value })}
        />
        <input
          className="input"
          placeholder="Max salary"
          value={filters.salaryMax}
          onChange={(e) => setFilters({ ...filters, salaryMax: e.target.value })}
        />
        {!institutionId && institutions?.length > 0 && (
          <select className="select" value={institutionFilter} onChange={(e) => setInstitutionFilter(e.target.value)}>
            <option value="">All institutions</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <select className="select" value={filters.status} onChange={(e) => setFilters({ ...filters, status: e.target.value })}>
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="table table--jobs">
        <div className="table-row table-row--head">
          <div>Title</div>
          <div>Company</div>
          <div>Location</div>
          <div>Status</div>
          <div>Institution</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No jobs found.</div></div>
        ) : (
          filteredRows.map((row) => (
            <div className="table-row" key={row.id}>
              <div className="title-cell">
                <strong>{row.title}</strong>
                <span>
                  {(row.category || 'General')}
                  {row.salary ? ` • ${row.salary}` : ''}
                </span>
              </div>
              <div>{row.company_name || '-'}</div>
              <div>{row.location || '-'}</div>
              <div><StatusPill status={row.is_active ? 'active' : 'inactive'} /></div>
              <div>{row.institution?.name || '-'}</div>
              <div className="actions">
                <div className="action-menu">
                  <button
                    className="ghost"
                    onClick={(e) => {
                      e.stopPropagation();
                      setOpenMenuId((prev) => (prev === row.id ? null : row.id));
                    }}
                  >
                    Manage
                  </button>
                  {openMenuId === row.id && (
                    <div className="action-menu-list" onClick={(e) => e.stopPropagation()}>
                      <button className="ghost" onClick={() => { setViewJob(row); setOpenMenuId(null); }}>
                        [i] View details
                      </button>
                      <button className="ghost" onClick={() => { setEditing(row); setOpenMenuId(null); }}>
                        [e] Edit job
                      </button>
                      <button className="ghost danger" onClick={() => { confirmDelete(row); setOpenMenuId(null); }}>
                        [x] Delete
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
      {viewJob && (
        <div className="modal-backdrop" onClick={() => setViewJob(null)}>
          <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">Job details</div>
            <div className="modal-message">{viewJob.title}</div>
            <div className="card-form">
              <div><strong>Company:</strong> {viewJob.company_name || '-'}</div>
              <div><strong>Location:</strong> {viewJob.location || '-'}</div>
              <div><strong>Work mode:</strong> {viewJob.work_mode || '-'}</div>
              <div><strong>Salary:</strong> {viewJob.salary || '-'}</div>
              <div><strong>Experience:</strong> {viewJob.experience_level || '-'}</div>
              <div><strong>Category:</strong> {viewJob.category || '-'}</div>
              <div><strong>Status:</strong> {viewJob.is_active ? 'Active' : 'Inactive'}</div>
            </div>
            {viewJob.overview && (
              <div className="card" style={{ marginTop: '12px' }}>
                <h3>Overview</h3>
                <p>{viewJob.overview}</p>
              </div>
            )}
            {viewJob.description && (
              <div className="card" style={{ marginTop: '12px' }}>
                <h3>Description</h3>
                <p>{viewJob.description}</p>
              </div>
            )}
            <div className="modal-actions">
              <button className="primary" onClick={() => setViewJob(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function InstitutionRequestsView({ institutionId }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [summary, setSummary] = useState(null);

  const loadRequests = async () => {
    if (!institutionId) return;
    setLoading(true);
    setError('');
    try {
      const data = await fetchJoinRequests(institutionId, { page, perPage: 15 });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load join requests');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadRequests().catch(() => {});
  }, [page, institutionId]);

  useEffect(() => {
    if (!institutionId) return;
    fetchInstitutionAnalytics(institutionId)
      .then((res) => setSummary(res?.metrics || null))
      .catch(() => setSummary(null));
  }, [institutionId]);

  async function handleDecision(id, action) {
    try {
      if (action === 'approve') {
        await approveJoinRequest(institutionId, id);
      } else {
        await rejectJoinRequest(institutionId, id);
      }
      setRows((prev) => prev.filter((r) => r.id !== id));
    } catch (err) {
      setError(err.message || 'Failed to update request');
    }
  }

  if (!institutionId) {
    return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Join requests</h2>
          <p>Approve alumni who want to join your institution.</p>
        </div>
      </div>

      {summary && (
        <div className="metrics-grid">
          <AnalyticsCard title="Members" value={summary.users_total ?? 0} subtitle="Total" chartType="line" />
          <AnalyticsCard title="Posts" value={summary.posts_total ?? 0} subtitle="Total" chartType="bar" />
          <AnalyticsCard title="Events" value={summary.events_total ?? 0} subtitle="Total" chartType="line" />
          <AnalyticsCard title="Donations" value={formatCurrency('GHS', summary.donations_total ?? 0)} subtitle="Raised" chartType="bar" />
        </div>
      )}

      {error && <div className="alert">{error}</div>}

      <div className="table">
        <div className="table-row table-row--head">
          <div>Name</div>
          <div>Email</div>
          <div>Year</div>
          <div>Department</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No pending requests.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div>{row.user?.name || 'Unknown'}</div>
              <div>{row.user?.email || '-'}</div>
              <div>{row.graduation_year || '-'}</div>
              <div>{row.department || row.course || '-'}</div>
              <div className="actions">
                <button className="primary" onClick={() => handleDecision(row.id, 'approve')}>Approve</button>
                <button className="ghost" onClick={() => handleDecision(row.id, 'reject')}>Reject</button>
              </div>
            </div>
          ))
        )}
      </div>

      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
    </div>
  );
}

function InstitutionDashboardView({ institutionId, scopeLabel, basePath = '/institution' }) {
  const [summary, setSummary] = useState(null);
  const [requests, setRequests] = useState([]);
  const [verificationCount, setVerificationCount] = useState(0);
  const [activeAdsCount, setActiveAdsCount] = useState(0);
  const [payments, setPayments] = useState([]);
  const [feeEnabled, setFeeEnabled] = useState(true);
  const [profile, setProfile] = useState(null);
  const [aiStats, setAiStats] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();
  const parseMetadata = (raw) => {
    if (!raw) return {};
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        return typeof parsed === 'object' && parsed ? parsed : {};
      } catch (_) {
        return {};
      }
    }
    return typeof raw === 'object' && raw ? raw : {};
  };
  const paymentsSummary = useMemo(() => {
    if (!payments.length) return null;
    return payments.reduce(
      (acc, row) => {
        const meta = parseMetadata(row.metadata);
        const fee = Number(meta?.platform_fee_amount ?? 0);
        const net = Number(meta?.net_amount ?? (Number(row.amount ?? 0) - fee));
        acc.total += Number(row.amount ?? 0);
        acc.fee += fee;
        acc.net += net;
        acc.currency = row.currency || acc.currency;
        return acc;
      },
      { total: 0, fee: 0, net: 0, currency: payments[0]?.currency || 'GHS' }
    );
  }, [payments]);

  useEffect(() => {
    if (!institutionId) return;
    setLoading(true);
    setError('');
    setProfile(null);
    const profilePromise = basePath.startsWith('/super')
      ? fetchInstitutionProfile(institutionId)
      : fetchMyInstitutionProfile();
    const requests = [
      fetchInstitutionAnalytics(institutionId),
      fetchJoinRequests(institutionId, { page: 1, perPage: 5 }),
      fetchVerificationRequests({ status: 'pending', institutionId, page: 1, perPage: 1 }),
      fetchAds({ status: 'active', institutionId, page: 1, perPage: 1 }),
      fetchTransactions({ institutionId, page: 1, perPage: 5 }),
      fetchSystemSettings(),
      profilePromise,
    ];
    if (basePath.startsWith('/super')) {
      requests.push(fetchAiPerformance());
    } else {
      requests.push(Promise.resolve(null));
    }
    Promise.all(requests)
      .then(([analytics, joins, verifications, ads, transactions, systemSettings, profileRes, aiPerformance]) => {
        setSummary(analytics?.metrics || null);
        setRequests(joins?.data || []);
        setVerificationCount(verifications?.meta?.total || 0);
        setActiveAdsCount(ads?.meta?.total || 0);
        setPayments(transactions?.data || []);
        const list = systemSettings?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        setFeeEnabled(map.platform_fee_enabled !== false);
        setProfile(profileRes?.institution || profileRes || null);
        setAiStats(aiPerformance?.stats || null);
      })
      .catch((err) => setError(err.message || 'Failed to load dashboard'))
      .finally(() => setLoading(false));
  }, [institutionId]);

  if (!institutionId) {
    return <div className="panel">No institution assigned. Please ask a super admin to assign your account.</div>;
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Institution dashboard</h2>
          <p>Quick overview of activity and pending requests.</p>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      {loading && <div className="table-row"><div>Loading...</div></div>}
      {error && <div className="alert">{error}</div>}
      {profile && (
        <div className="card">
          <div className="card-header">
            <div>
              <h3>School profile</h3>
              <p>Public information visible to alumni.</p>
            </div>
            {basePath === '/institution' && (
              <button className="ghost" onClick={() => navigate('/institution/profile')}>
                Edit profile
              </button>
            )}
          </div>
          <div className="profile-grid">
            <div>
              <div className="profile-label">Logo</div>
              <div className="profile-value">
                <div className="brand-badge">
                  {profile.logo_url ? <img src={resolveMediaUrl(profile.logo_url)} alt="Logo" /> : <span>—</span>}
                </div>
              </div>
            </div>
            <div>
              <div className="profile-label">Banner</div>
              <div className="profile-value">
                <div className="brand-badge" style={{ width: 140, height: 72 }}>
                  {profile.banner_url ? <img src={resolveMediaUrl(profile.banner_url)} alt="Banner" /> : <span>—</span>}
                </div>
              </div>
            </div>
            <div>
              <div className="profile-label">Name</div>
              <div className="profile-value">{profile.name || '-'}</div>
            </div>
            <div>
              <div className="profile-label">Location</div>
              <div className="profile-value">{profile.location || '-'}</div>
            </div>
            <div>
              <div className="profile-label">Website</div>
              <div className="profile-value">{profile.website || '-'}</div>
            </div>
            <div>
              <div className="profile-label">Email</div>
              <div className="profile-value">{profile.email || '-'}</div>
            </div>
            <div>
              <div className="profile-label">Phone</div>
              <div className="profile-value">{profile.phone || '-'}</div>
            </div>
            <div>
              <div className="profile-label">Address</div>
              <div className="profile-value">{profile.address || '-'}</div>
            </div>
            <div>
              <div className="profile-label">Motto</div>
              <div className="profile-value">{profile.motto || '-'}</div>
            </div>
          </div>
          {profile.description ? (
            <div className="profile-bio">{profile.description}</div>
          ) : null}
        </div>
      )}
      {summary && (
        <div className="metrics-grid">
          <AnalyticsCard
            title="Members"
            value={summary.users_total ?? 0}
            subtitle="Total"
            chartType="line"
            onClick={() => navigate(`${basePath}/analytics`)}
          />
          <AnalyticsCard
            title="Posts"
            value={summary.posts_total ?? 0}
            subtitle="Total"
            chartType="bar"
            onClick={() => navigate(`${basePath}/analytics`)}
          />
          <AnalyticsCard
            title="Events"
            value={summary.events_total ?? 0}
            subtitle="Total"
            chartType="line"
            onClick={() => navigate(`${basePath}/events`)}
          />
          <AnalyticsCard
            title="Donations"
            value={formatCurrency('GHS', summary.donations_total ?? 0)}
            subtitle="Raised"
            chartType="bar"
            onClick={() => navigate(`${basePath}/donations`)}
          />
          <AnalyticsCard
            title="Pending verifications"
            value={verificationCount}
            subtitle="Awaiting review"
            chartType="line"
            onClick={() => navigate(`${basePath}/verification`)}
          />
          <AnalyticsCard
            title="Active ads"
            value={activeAdsCount}
            subtitle="Running now"
            chartType="bar"
            onClick={() => navigate(`${basePath}/ads`)}
          />
          {basePath.startsWith('/super') && aiStats && (
            <AnalyticsCard
              title="AI CTR"
              value={`${aiStats.ctr_percent ?? 0}%`}
              subtitle={`${aiStats.recommendations_clicked ?? 0} clicks`}
              chartType="line"
              onClick={() => navigate('/super/ai-controls')}
            />
          )}
        </div>
      )}
      <div className="table">
        <div className="table-row table-row--head">
          <div>Recent join requests</div>
          <div>Email</div>
          <div>Year</div>
          <div>Department</div>
        </div>
        {requests.length === 0 ? (
          <div className="table-row"><div>No recent requests.</div></div>
        ) : (
          requests.map((row) => (
            <div className="table-row" key={row.id}>
              <div>{row.user?.name || 'Unknown'}</div>
              <div>{row.user?.email || '-'}</div>
              <div>{row.graduation_year || '-'}</div>
              <div>{row.department || row.course || '-'}</div>
            </div>
          ))
        )}
      </div>
      <div className="table">
        {paymentsSummary && (
          <div className="pill-group" style={{ marginBottom: 12 }}>
            <span className="pill">Total {formatCurrency(paymentsSummary.currency, paymentsSummary.total.toFixed(2))}</span>
            <span className="pill">Fees {formatCurrency(paymentsSummary.currency, paymentsSummary.fee.toFixed(2))}</span>
            <span className="pill">Net {formatCurrency(paymentsSummary.currency, paymentsSummary.net.toFixed(2))}</span>
            <span className="pill">{feeEnabled ? 'Fee enabled' : 'Fee disabled'}</span>
          </div>
        )}
        <div className="table-row table-row--head">
          <div>Recent payments</div>
          <div>Type</div>
          <div>Status</div>
          <div>Amount</div>
          <div>Fee</div>
          <div>Net</div>
          <div>Date</div>
        </div>
        {payments.length === 0 ? (
          <div className="table-row"><div>No recent payments.</div></div>
        ) : (
          payments.map((row) => (
            <div className="table-row" key={row.id}>
              {(() => {
                const meta = parseMetadata(row.metadata);
                const feeAmount = meta?.platform_fee_amount;
                const netAmount = meta?.net_amount;
                const feePercent = meta?.platform_fee_percent;
                const donationTransactionId = meta?.donation_transaction_id;
                const feeTitle = feePercent !== undefined && feePercent !== null
                  ? `Fee ${feePercent}%${donationTransactionId ? ` • Donation txn ${donationTransactionId}` : ''}`
                  : donationTransactionId
                    ? `Donation txn ${donationTransactionId}`
                    : '';
                return (
                  <>
              <div>{row.user?.name || row.reference || 'Payment'}</div>
              <div>{row.type || '-'}</div>
              <div><StatusPill status={row.status} /></div>
              <div>{formatCurrency(row.currency, row.amount)}</div>
              <div title={feeTitle}>
                {feeAmount !== undefined && feeAmount !== null ? formatCurrency(row.currency, feeAmount) : '-'}
                {feeTitle ? <span className="hint" style={{ marginLeft: 6 }}>ⓘ</span> : null}
              </div>
              <div title={feeTitle}>
                {netAmount !== undefined && netAmount !== null ? formatCurrency(row.currency, netAmount) : '-'}
              </div>
              <div>{row.created_at ? new Date(row.created_at).toLocaleDateString() : '-'}</div>
                  </>
                );
              })()}
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function ModerationView({ mode, basePath }) {
  const [status, setStatus] = useState('pending');
  const [query, setQuery] = useState('');
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [bulkLoading, setBulkLoading] = useState(false);
  const [error, setError] = useState('');
  const [previewPost, setPreviewPost] = useState(null);
  const [profileUser, setProfileUser] = useState(null);
  const [profileData, setProfileData] = useState(null);
  const navigate = useNavigate();

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = mode === 'posts'
        ? await fetchPostReports({ status, query, page, perPage: 15 })
        : await fetchUserReports({ status, query, page, perPage: 15 });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load reports');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [status, query, page, mode]);

  async function handleResolve(id, nextStatus) {
    try {
      if (mode === 'posts') {
        await resolvePostReport(id, nextStatus);
      } else {
        await resolveUserReport(id, nextStatus);
      }
      setRows((prev) => prev.filter((r) => r.id !== id));
    } catch (err) {
      setError(err.message || 'Failed to resolve report');
    }
  }

  async function handleBulk(nextStatus) {
    if (!rows.length) return;
    setBulkLoading(true);
    try {
      await Promise.all(
        rows.map((row) =>
          mode === 'posts' ? resolvePostReport(row.id, nextStatus) : resolveUserReport(row.id, nextStatus)
        )
      );
      loadData();
    } catch (err) {
      setError(err.message || 'Failed to resolve reports');
    } finally {
      setBulkLoading(false);
    }
  }

  function exportCsv() {
    if (!rows.length) return;
    const headers = mode === 'posts'
      ? ['id', 'reporter', 'post_author', 'reason', 'status', 'created_at']
      : ['id', 'reporter', 'reported_user', 'reason', 'status', 'created_at'];
    const lines = rows.map((row) => {
      const reporter = row.reporter?.name || '';
      const subject = mode === 'posts' ? row.post?.user?.name || '' : row.reported_user?.name || '';
      const reason = row.reason || '';
      const statusVal = row.status || '';
      const created = row.created_at || '';
      return [row.id, reporter, subject, reason, statusVal, created]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `${mode}-reports.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  async function openProfile(user) {
    if (!user?.id) return;
    setProfileUser(user);
    try {
      const data = await fetchUserProfile(user.id);
      const fetchedUser = data?.user || data || null;
      setProfileUser(fetchedUser || user);
      setProfileData(fetchedUser || null);
    } catch (_) {
      setProfileData(null);
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>{mode === 'posts' ? 'Post reports' : 'User reports'}</h2>
          <p>Resolve reported content and accounts.</p>
        </div>
        <div className="panel-actions">
          <div className="subnav">
            <NavLink
              to={`${basePath}/users`}
              className={({ isActive }) => `subnav-item${isActive ? ' subnav-item--active' : ''}`}
            >
              User reports
            </NavLink>
            <NavLink
              to={`${basePath}/posts`}
              className={({ isActive }) => `subnav-item${isActive ? ' subnav-item--active' : ''}`}
            >
              Post reports
            </NavLink>
          </div>
          <select
            className="select"
            value={mode}
            onChange={(e) => {
              const next = e.target.value;
              navigate(`${basePath}/${next}`);
            }}
          >
            <option value="users">User reports</option>
            <option value="posts">Post reports</option>
          </select>
          <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
            <option value="dismissed">Dismissed</option>
          </select>
          <input
            className="input"
            placeholder="Filter by reason"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setPage(1);
            }}
          />
        </div>
      </div>

      <div className="bulk-actions">
        <button className="ghost" onClick={() => handleBulk('resolved')} disabled={bulkLoading || !rows.length}>
          Resolve all
        </button>
        <button className="ghost" onClick={() => handleBulk('dismissed')} disabled={bulkLoading || !rows.length}>
          Dismiss all
        </button>
        <button className="ghost" onClick={exportCsv} disabled={!rows.length}>
          Export CSV
        </button>
      </div>

      {error && <div className="alert">{error}</div>}

      <div className={`table ${mode === 'posts' ? 'table--wide' : ''}`}>
        <div className="table-row table-row--head">
          <div>Reporter</div>
          <div>{mode === 'posts' ? 'Post Author' : 'Reported'}</div>
          {mode === 'posts' && <div>Post</div>}
          <div>Reason</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No reports found.</div></div>
        ) : (
          rows.map((row) => {
            const post = row.post;
            const previewText = post?.content || '';
            const media = post?.media && post.media.length ? post.media[0] : null;
            const mediaUrl = media?.thumbnail_url || media?.url || '';
            return (
              <div className="table-row" key={row.id}>
                <div className="link" onClick={() => openProfile(row.reporter)}>{row.reporter?.name || '-'}</div>
                <div className="link" onClick={() => openProfile(mode === 'posts' ? post?.user : row.reported_user)}>
                  {mode === 'posts' ? post?.user?.name || '-' : row.reported_user?.name || '-'}
                </div>
                {mode === 'posts' && (
                  <div className="post-preview" onClick={() => setPreviewPost(post)}>
                    {mediaUrl && <img src={mediaUrl} alt="media" />}
                    <div className="post-preview-text">{previewText || 'No content'}</div>
                  </div>
                )}
                <div>{row.reason || '-'}</div>
                <div><StatusPill status={row.status} /></div>
                <div className="actions">
                  <button className="ghost" onClick={() => handleResolve(row.id, 'resolved')}>Resolve</button>
                  <button className="ghost" onClick={() => handleResolve(row.id, 'dismissed')}>Dismiss</button>
                </div>
              </div>
            );
          })
        )}
      </div>

      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>

      <PostPreviewModal open={!!previewPost} post={previewPost} onClose={() => setPreviewPost(null)} />
      <UserProfileModal
        open={!!profileUser}
        user={profileUser}
        profile={profileData?.profile}
        onClose={() => { setProfileUser(null); setProfileData(null); }}
        onSaved={() => { setProfileUser(null); setProfileData(null); }}
      />
    </div>
  );
}

function ReportsView({ institutions = [], isSuper = false }) {
  const [platformReport, setPlatformReport] = useState(null);
  const [stats, setStats] = useState({
    posts: { pending: 0, resolved: 0, dismissed: 0 },
    users: { pending: 0, resolved: 0, dismissed: 0 },
  });
  const [trend, setTrend] = useState([]);
  const [reasons, setReasons] = useState({ posts: [], users: [] });
  const [resolution, setResolution] = useState({ posts: 0, users: 0 });
  const [slaBuckets, setSlaBuckets] = useState({ posts: {}, users: {} });
  const [institutionBreakdown, setInstitutionBreakdown] = useState({ posts: [], users: [] });
  const [latestRows, setLatestRows] = useState([]);
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [typeFilter, setTypeFilter] = useState('posts');
  const [statusFilter, setStatusFilter] = useState('');
  const [query, setQuery] = useState('');
  const [range, setRange] = useState({ from: '', to: '' });
  const [institutionId, setInstitutionId] = useState('');
  const [loading, setLoading] = useState(false);
  const [tableLoading, setTableLoading] = useState(false);
  const [error, setError] = useState('');
  const [detailState, setDetailState] = useState({ open: false, report: null, type: 'post' });
  const [reportReasons, setReportReasons] = useState([]);
  const [reasonInput, setReasonInput] = useState('');
  const [reasonPresets, setReasonPresets] = useState([
    'Harassment',
    'Impersonation',
    'Spam',
    'Hate speech',
    'Violence',
    'Scam',
    'Nudity',
    'Other',
  ]);
  const [savingReasons, setSavingReasons] = useState(false);
  const [schoolStatusFilter, setSchoolStatusFilter] = useState('');
  const [schoolLocationFilter, setSchoolLocationFilter] = useState('');
  const [schoolReportOpen, setSchoolReportOpen] = useState(false);
  const navigate = useNavigate();

  const analyticsParams = {
    from: range.from || undefined,
    to: range.to || undefined,
    institutionId: isSuper && institutionId ? Number(institutionId) : undefined,
  };

  useEffect(() => {
    if (!isSuper) {
      setPlatformReport(null);
      return;
    }
    fetchPlatformAnalytics({
      from: range.from || undefined,
      to: range.to || undefined,
    })
      .then((data) => setPlatformReport(data || null))
      .catch((err) => {
        setPlatformReport(null);
        setError(err.message || 'Failed to load school summary report');
      });
  }, [isSuper, range.from, range.to]);

  useEffect(() => {
    setLoading(true);
    fetchReportsAnalytics(analyticsParams)
      .then((data) => {
        const counts = data?.counts || {};
        setStats({
          posts: counts.posts || { pending: 0, resolved: 0, dismissed: 0 },
          users: counts.users || { pending: 0, resolved: 0, dismissed: 0 },
        });
        setReasons(data?.reasons || { posts: [], users: [] });
        setTrend(data?.trend || []);
        setResolution(data?.resolution_time_seconds || { posts: 0, users: 0 });
        setSlaBuckets(data?.sla_buckets || { posts: {}, users: {} });
        setInstitutionBreakdown(data?.institution_breakdown || { posts: [], users: [] });
      })
      .catch((err) => setError(err.message || 'Failed to load report analytics'))
      .finally(() => setLoading(false));
  }, [range.from, range.to, institutionId, isSuper]);

  useEffect(() => {
    fetchSystemSettings()
      .then((data) => {
        const list = data?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        setReportReasons(map.report_categories || []);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    Promise.all([
      fetchPostReports({ status: '', page: 1, perPage: 10, ...analyticsParams }),
      fetchUserReports({ status: '', page: 1, perPage: 10, ...analyticsParams }),
    ])
      .then(([latestPosts, latestUsers]) => {
        const postRows = (latestPosts?.data || []).map((row) => ({ ...row, _type: 'post' }));
        const userRows = (latestUsers?.data || []).map((row) => ({ ...row, _type: 'user' }));
        const merged = [...postRows, ...userRows].sort((a, b) => {
          const aTime = new Date(a.created_at || 0).getTime();
          const bTime = new Date(b.created_at || 0).getTime();
          return bTime - aTime;
        }).slice(0, 10);
        setLatestRows(merged);
      })
      .catch(() => {});
  }, [range.from, range.to, institutionId, isSuper]);

  useEffect(() => {
    setTableLoading(true);
    setError('');
    const fetcher = typeFilter === 'users' ? fetchUserReports : fetchPostReports;
    fetcher({
      status: statusFilter,
      query,
      page,
      perPage: 15,
      ...analyticsParams,
    })
      .then((res) => {
        setRows(res?.data || []);
        setMeta(res?.meta || null);
      })
      .catch((err) => setError(err.message || 'Failed to load report table'))
      .finally(() => setTableLoading(false));
  }, [typeFilter, statusFilter, query, page, range.from, range.to, institutionId, isSuper]);

  const chartData = {
    labels: ['Pending', 'Resolved', 'Dismissed'],
    datasets: [
      {
        label: 'Post reports',
        data: [stats.posts.pending, stats.posts.resolved, stats.posts.dismissed],
        backgroundColor: 'rgba(37, 99, 235, 0.6)',
      },
      {
        label: 'User reports',
        data: [stats.users.pending, stats.users.resolved, stats.users.dismissed],
        backgroundColor: 'rgba(15, 23, 42, 0.6)',
      },
    ],
  };

  const topReasons = useMemo(() => {
    const map = new Map();
    [...(reasons.posts || []), ...(reasons.users || [])].forEach((item) => {
      if (!item?.reason) return;
      map.set(item.reason, (map.get(item.reason) || 0) + (item.count || 0));
    });
    return [...map.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5);
  }, [reasons]);

  const reasonChart = {
    labels: topReasons.map(([reason]) => reason),
    datasets: [
      {
        label: 'Reports',
        data: topReasons.map(([, count]) => count),
        backgroundColor: 'rgba(14, 116, 144, 0.6)',
      },
    ],
  };

  const trendChart = {
    labels: trend.map((row) => row.day),
    datasets: [
      {
        label: 'Reports',
        data: trend.map((row) => row.total),
        borderColor: 'rgba(59, 130, 246, 0.9)',
        backgroundColor: 'rgba(59, 130, 246, 0.2)',
        fill: true,
      },
    ],
  };

  function formatDuration(seconds) {
    const value = Number(seconds || 0);
    if (!value) return '—';
    const mins = Math.round(value / 60);
    if (mins < 60) return `${mins} min`;
    const hours = (mins / 60).toFixed(1);
    return `${hours} hr`;
  }

  const slaChart = {
    labels: ['<24h', '24-48h', '48h+'],
    datasets: [
      {
        label: 'Post reports',
        data: [
          slaBuckets.posts?.under_24h || 0,
          slaBuckets.posts?.under_48h || 0,
          slaBuckets.posts?.over_48h || 0,
        ],
        backgroundColor: 'rgba(37, 99, 235, 0.6)',
      },
      {
        label: 'User reports',
        data: [
          slaBuckets.users?.under_24h || 0,
          slaBuckets.users?.under_48h || 0,
          slaBuckets.users?.over_48h || 0,
        ],
        backgroundColor: 'rgba(15, 23, 42, 0.6)',
      },
    ],
  };

  const institutionChart = {
    labels: (() => {
      const map = new Map();
      [...(institutionBreakdown.posts || []), ...(institutionBreakdown.users || [])].forEach((row) => {
        if (!row?.name) return;
        map.set(row.name, (map.get(row.name) || 0) + (row.count || 0));
      });
      return [...map.keys()];
    })(),
    datasets: [
      {
        label: 'Reports',
        data: (() => {
          const map = new Map();
          [...(institutionBreakdown.posts || []), ...(institutionBreakdown.users || [])].forEach((row) => {
            if (!row?.name) return;
            map.set(row.name, (map.get(row.name) || 0) + (row.count || 0));
          });
          return [...map.values()];
        })(),
        backgroundColor: 'rgba(14, 116, 144, 0.6)',
      },
    ],
  };

  const schoolSummary = platformReport?.institution_summary?.schools || [];
  const schoolLocations = useMemo(() => {
    return [...new Set(schoolSummary.map((row) => row.location).filter(Boolean))].sort((a, b) => a.localeCompare(b));
  }, [schoolSummary]);
  const filteredSchoolSummary = useMemo(() => {
    return schoolSummary.filter((row) => {
      const statusOk = !schoolStatusFilter || row.status === schoolStatusFilter;
      const locationOk = !schoolLocationFilter || row.location === schoolLocationFilter;
      return statusOk && locationOk;
    });
  }, [schoolSummary, schoolStatusFilter, schoolLocationFilter]);
  const topGrowingSchools = useMemo(() => {
    const backendRows = platformReport?.institution_summary?.top_growing || [];
    if (backendRows.length) {
      return backendRows.filter((row) => {
        const statusOk = !schoolStatusFilter || row.status === schoolStatusFilter;
        const locationOk = !schoolLocationFilter || row.location === schoolLocationFilter;
        return statusOk && locationOk;
      }).slice(0, 5);
    }
    return [...filteredSchoolSummary]
      .sort((a, b) => (b.new_users_count || 0) - (a.new_users_count || 0))
      .slice(0, 5);
  }, [filteredSchoolSummary, platformReport, schoolLocationFilter, schoolStatusFilter]);
  const schoolsWithoutAdmins = useMemo(() => filteredSchoolSummary.filter((row) => (row.admins_count || 0) === 0), [filteredSchoolSummary]);
  const lowActivitySchools = useMemo(() => filteredSchoolSummary.filter((row) => ['inactive_30d', 'inactive_60d', 'inactive_90d'].includes(row.inactive_bucket)), [filteredSchoolSummary]);
  const schoolSummaryChart = {
    labels: filteredSchoolSummary.slice(0, 8).map((row) => row.name),
    datasets: [
      {
        label: 'Users',
        data: filteredSchoolSummary.slice(0, 8).map((row) => row.users_count || 0),
        backgroundColor: 'rgba(37, 99, 235, 0.7)',
      },
      {
        label: 'Admins',
        data: filteredSchoolSummary.slice(0, 8).map((row) => row.admins_count || 0),
        backgroundColor: 'rgba(14, 116, 144, 0.65)',
      },
    ],
  };

  function exportSchoolSummaryCsv() {
    if (!filteredSchoolSummary.length) return;
    const headers = ['school_id', 'school_name', 'status', 'location', 'users', 'new_users', 'admins', 'year_groups', 'posts', 'events', 'attendance', 'donations', 'pending_verifications', 'inactive_days'];
    const lines = filteredSchoolSummary.map((row) => [
      row.school_id || '',
      row.name || '',
      row.status || '',
      row.location || '',
      row.users_count || 0,
      row.new_users_count || 0,
      row.admins_count || 0,
      row.year_groups_count || 0,
      row.posts_count || 0,
      row.events_count || 0,
      row.event_attendance_total || 0,
      row.donations_total || 0,
      row.pending_verifications_count || 0,
      row.inactive_days ?? '',
    ].map((value) => `"${String(value).replace(/"/g, '""')}"`).join(','));
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'school-summary.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  async function exportSchoolSummaryPdf() {
    try {
      const blob = await downloadPlatformSchoolsPdf({
        from: range.from || undefined,
        to: range.to || undefined,
        status: schoolStatusFilter || undefined,
        location: schoolLocationFilter || undefined,
      });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'school-summary-report.pdf');
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(err.message || 'Failed to export school summary PDF');
    }
  }

  function exportCsv(rowsToExport, filename) {
    if (!rowsToExport.length) return;
    const headers = ['type', 'id', 'reporter', 'subject', 'reason', 'status', 'created_at'];
    const lines = rowsToExport.map((row) => {
      const isPost = row._type ? row._type === 'post' : typeFilter === 'posts';
      const reporter = row.reporter?.name || '';
      const subject = isPost ? row.post?.user?.name : row.reported_user?.name;
      return [
        isPost ? 'post' : 'user',
        row.id,
        reporter || '',
        subject || '',
        row.reason || '',
        row.status || '',
        row.created_at || '',
      ]
        .map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  async function saveReasons(nextReasons) {
    setSavingReasons(true);
    setError('');
    try {
      await updateSystemSettings({ report_categories: nextReasons });
      setReportReasons(nextReasons);
    } catch (err) {
      setError(err.message || 'Failed to save reasons');
    } finally {
      setSavingReasons(false);
    }
  }

  function moveReason(fromIndex, toIndex) {
    if (fromIndex === toIndex) return;
    const next = [...reportReasons];
    const [item] = next.splice(fromIndex, 1);
    next.splice(toIndex, 0, item);
    setReportReasons(next);
    saveReasons(next);
  }

  function toggleReason(reason) {
    const exists = reportReasons.includes(reason);
    if (exists) {
      saveReasons(reportReasons.filter((r) => r !== reason));
    } else {
      saveReasons([...reportReasons, reason]);
    }
  }

  async function exportPdf({ type = 'all', filename = 'reports.pdf' } = {}) {
    try {
      const blob = await downloadReportsPdf({
        type,
        status: statusFilter || undefined,
        query: query || undefined,
        from: range.from || undefined,
        to: range.to || undefined,
        institutionId: isSuper && institutionId ? Number(institutionId) : undefined,
      });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', filename);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(err.message || 'Failed to export PDF');
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Reports</h2>
          <p>Review content and user reports across the platform.</p>
        </div>
        <div className="panel-actions">
          <input
            className="input"
            type="date"
            value={range.from}
            onChange={(e) => setRange((prev) => ({ ...prev, from: e.target.value }))}
          />
          <input
            className="input"
            type="date"
            value={range.to}
            onChange={(e) => setRange((prev) => ({ ...prev, to: e.target.value }))}
          />
          {isSuper && (
            <select
              className="select"
              value={institutionId}
              onChange={(e) => {
                setInstitutionId(e.target.value);
                setPage(1);
              }}
            >
              <option value="">All institutions</option>
              {institutions.map((inst) => (
                <option key={inst.id} value={inst.id}>{inst.name}</option>
              ))}
            </select>
          )}
        </div>
      </div>
      {error && <div className="alert">{error}</div>}
      {isSuper && (
        <>
          <div className="metrics-grid reports-metrics">
            <AnalyticsCard
              title="Schools on platform"
              value={platformReport?.metrics?.institutions_total ?? '—'}
              subtitle={`${platformReport?.metrics?.active_schools_total ?? 0} active · ${platformReport?.metrics?.suspended_schools_total ?? 0} suspended`}
              chartType="bar"
            />
            <AnalyticsCard
              title="Users across schools"
              value={platformReport?.institution_summary?.users_across_schools ?? '—'}
              subtitle={`${platformReport?.metrics?.avg_users_per_school ?? 0} avg per school`}
              chartType="line"
            />
            <AnalyticsCard
              title="Institution admins"
              value={platformReport?.metrics?.institution_admins_total ?? '—'}
              subtitle={`${platformReport?.metrics?.pending_schools_total ?? 0} schools pending activation`}
              chartType="bar"
            />
            <AnalyticsCard
              title="Largest school"
              value={platformReport?.institution_summary?.largest_school?.users_count ?? '—'}
              subtitle={platformReport?.institution_summary?.largest_school?.name || 'No schools yet'}
              chartType="line"
            />
          </div>
          <div className="grid-2 reports-grid">
            <div className="card reports-card reports-card--soft">
              <div className="card-header">
                <div>
                  <h3><span className="section-icon section-icon--institutions" />Members per school</h3>
                  <p>See which schools have the largest alumni communities right now.</p>
                </div>
                <div className="panel-actions reports-actions">
                  <select className="select" value={schoolStatusFilter} onChange={(e) => setSchoolStatusFilter(e.target.value)}>
                    <option value="">All statuses</option>
                    <option value="active">Active</option>
                    <option value="suspended">Suspended</option>
                    <option value="pending">Pending</option>
                    <option value="rejected">Rejected</option>
                  </select>
                  <select className="select" value={schoolLocationFilter} onChange={(e) => setSchoolLocationFilter(e.target.value)}>
                    <option value="">All locations</option>
                    {schoolLocations.map((location) => (
                      <option key={location} value={location}>{location}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="chart reports-chart">
                <Bar data={schoolSummaryChart} options={{ responsive: true, plugins: { legend: { position: 'bottom' } } }} />
              </div>
            </div>
            <div className="card reports-card reports-card--soft">
              <div className="card-header">
                <div>
                  <h3><span className="section-icon section-icon--latest" />School health snapshot</h3>
                  <p>Quick operational picture across all schools.</p>
                </div>
              </div>
              <div className="detail-grid reports-summary-strip">
                <div><strong>Active schools</strong><span>{platformReport?.metrics?.active_schools_total ?? 0}</span></div>
                <div><strong>Suspended schools</strong><span>{platformReport?.metrics?.suspended_schools_total ?? 0}</span></div>
                <div><strong>Pending schools</strong><span>{platformReport?.metrics?.pending_schools_total ?? 0}</span></div>
                <div><strong>Total school admins</strong><span>{platformReport?.metrics?.institution_admins_total ?? 0}</span></div>
                <div><strong>Average users / school</strong><span>{platformReport?.metrics?.avg_users_per_school ?? 0}</span></div>
                <div><strong>Most populated school</strong><span>{platformReport?.institution_summary?.largest_school?.name || '—'}</span></div>
              </div>
            </div>
          </div>
          <div className="grid-2 reports-grid">
            <div className="card reports-card reports-card--soft">
              <div className="card-header">
                <div>
                  <h3><span className="section-icon section-icon--trend" />Top-growing schools</h3>
                  <p>New alumni added during the selected period.</p>
                </div>
              </div>
              <div className="table table--wide reports-table">
                <div className="table-row table-row--head">
                  <div>School</div>
                  <div>School ID</div>
                  <div>New users</div>
                  <div>Total users</div>
                </div>
                {!topGrowingSchools.length ? (
                  <div className="table-row"><div>No growth data yet.</div></div>
                ) : (
                  topGrowingSchools.map((row) => (
                    <div className="table-row" key={`growth-${row.id}`}>
                      <div className="title-cell">
                        <strong>{row.name}</strong>
                        <span>{row.location || 'No location yet'}</span>
                      </div>
                      <div>{row.school_id || '-'}</div>
                      <div>{row.new_users_count ?? 0}</div>
                      <div>{row.users_count ?? 0}</div>
                    </div>
                  ))
                )}
              </div>
            </div>
            <div className="card reports-card reports-card--soft">
              <div className="card-header">
                <div>
                  <h3><span className="section-icon section-icon--status" />Schools needing attention</h3>
                  <p>Spot schools without admins or with very low activity.</p>
                </div>
              </div>
              <div className="detail-grid reports-summary-strip">
                <div><strong>Schools without admins</strong><span>{schoolsWithoutAdmins.length}</span></div>
                <div><strong>Low-activity schools</strong><span>{lowActivitySchools.length}</span></div>
                <div><strong>Inactive 60+ days</strong><span>{(platformReport?.institution_summary?.inactive_counts?.inactive_60d || 0) + (platformReport?.institution_summary?.inactive_counts?.inactive_90d || 0)}</span></div>
                <div><strong>Pending verifications</strong><span>{filteredSchoolSummary.reduce((sum, row) => sum + (row.pending_verifications_count || 0), 0)}</span></div>
                <div><strong>Most recent period</strong><span>{platformReport?.institution_summary?.period?.from || '—'} → {platformReport?.institution_summary?.period?.to || '—'}</span></div>
                <div><strong>Filtered schools</strong><span>{filteredSchoolSummary.length}</span></div>
              </div>
              <div className="table table--wide reports-table reports-attention-table" style={{ marginTop: 12 }}>
                <div className="table-row table-row--head">
                  <div>School</div>
                  <div>Issue</div>
                  <div>Users</div>
                  <div>Admins</div>
                </div>
                {[...schoolsWithoutAdmins, ...lowActivitySchools.filter((row) => (row.admins_count || 0) > 0)]
                  .slice(0, 8)
                  .map((row) => (
                    <div className="table-row" key={`attention-${row.id}`}>
                      <div className="title-cell">
                        <strong>{row.name}</strong>
                        <span>{row.school_id || '-'}</span>
                      </div>
                      <div>
                        {(row.admins_count || 0) === 0
                          ? 'No admin assigned'
                          : (row.pending_verifications_count || 0) > 0
                            ? 'Pending verifications'
                            : 'Low activity'}
                      </div>
                    <div>{row.users_count ?? 0}</div>
                    <div>{row.admins_count ?? 0}</div>
                  </div>
                  ))}
              </div>
            </div>
          </div>
          <div className="card reports-card">
            <div className="card-header">
              <div>
                <h3><span className="section-icon section-icon--table" />All schools report</h3>
                <p>A meaningful snapshot of every school, including users, admins, year groups, posts, and events.</p>
              </div>
              <div className="panel-actions reports-actions">
                <button className="ghost" onClick={exportSchoolSummaryCsv} disabled={!filteredSchoolSummary.length}>Export CSV</button>
                <button className="ghost" onClick={exportSchoolSummaryPdf} disabled={!filteredSchoolSummary.length}>Export PDF</button>
                <button className="primary reports-disclosure" onClick={() => setSchoolReportOpen((prev) => !prev)}>
                  <span>{schoolReportOpen ? 'Hide report' : 'Show report'}</span>
                  <span>{schoolReportOpen ? '−' : '+'}</span>
                </button>
              </div>
            </div>
            {schoolReportOpen && (
              <div className="table table--wide reports-table">
                <div className="table-row table-row--head">
                  <div>School</div>
                  <div>School ID</div>
                  <div>Status</div>
                  <div>Location</div>
                  <div>Users</div>
                  <div>New users</div>
                  <div>Admins</div>
                  <div>Year groups</div>
                  <div>Posts</div>
                  <div>Events</div>
                  <div>Attendance</div>
                  <div>Donations</div>
                  <div>Verifications</div>
                  <div>Inactive</div>
                </div>
                {!filteredSchoolSummary.length ? (
                  <div className="table-row"><div>No schools found.</div></div>
                ) : (
                  filteredSchoolSummary.map((row) => (
                    <div className="table-row" key={`school-summary-${row.id}`}>
                      <div className="title-cell">
                        <strong>{row.name}</strong>
                        <span>{row.location || 'No location yet'}</span>
                      </div>
                      <div>{row.school_id || '-'}</div>
                      <div><StatusPill status={row.status} /></div>
                      <div>{row.location || '-'}</div>
                      <div>{row.users_count ?? 0}</div>
                      <div>{row.new_users_count ?? 0}</div>
                      <div>{row.admins_count ?? 0}</div>
                      <div>{row.year_groups_count ?? 0}</div>
                      <div>{row.posts_count ?? 0}</div>
                      <div>{row.events_count ?? 0}</div>
                      <div>{row.event_attendance_total ?? 0}</div>
                      <div>{formatCurrency('GHS', row.donations_total ?? 0)}</div>
                      <div>{row.pending_verifications_count ?? 0}</div>
                      <div>{row.inactive_days == null ? 'No activity yet' : `${row.inactive_days} days`}</div>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>
        </>
      )}
      <div className="metrics-grid reports-metrics">
        <AnalyticsCard title="Pending post reports" value={loading ? '—' : stats.posts.pending} subtitle="Awaiting review" chartType="bar" />
        <AnalyticsCard title="Pending user reports" value={loading ? '—' : stats.users.pending} subtitle="Awaiting review" chartType="bar" />
        <AnalyticsCard title="Resolved reports" value={loading ? '—' : (stats.posts.resolved + stats.users.resolved)} subtitle="All types" chartType="line" />
        <AnalyticsCard title="Dismissed reports" value={loading ? '—' : (stats.posts.dismissed + stats.users.dismissed)} subtitle="All types" chartType="line" />
        <AnalyticsCard title="Avg post resolution" value={formatDuration(resolution.posts)} subtitle="Mean time" chartType="line" />
        <AnalyticsCard title="Avg user resolution" value={formatDuration(resolution.users)} subtitle="Mean time" chartType="line" />
      </div>
      <div className="grid-2 reports-grid">
        <div className="card reports-card reports-card--soft">
          <div className="card-header">
            <div>
              <h3><span className="section-icon section-icon--status" />Report status breakdown</h3>
              <p>Compare post vs user reports by status.</p>
            </div>
          </div>
          <div className="chart reports-chart">
            <Bar data={chartData} options={{ responsive: true, plugins: { legend: { position: 'bottom' } } }} />
          </div>
        </div>
        <div className="card reports-card reports-card--soft">
          <div className="card-header">
            <div>
              <h3><span className="section-icon section-icon--reasons" />Top reasons</h3>
              <p>Most common report reasons.</p>
            </div>
          </div>
          <div className="chart reports-chart">
            <Bar data={reasonChart} options={{ responsive: true, plugins: { legend: { display: false } } }} />
          </div>
        </div>
      </div>
        <div className="card report-reasons-card reports-card">
          <div className="card-header">
            <div>
              <h3>Report reasons</h3>
              <p>Manage the reasons available when users report content or users.</p>
            </div>
            <button
              className="ghost"
              onClick={() => saveReasons(reportReasons)}
              disabled={savingReasons}
            >
              {savingReasons ? 'Saving...' : 'Save reasons'}
            </button>
          </div>
          <div className="report-reasons-grid">
            <div className="report-reasons-column">
              <div className="section-title">Enabled reasons</div>
              <div className="section-subtitle">Drag to reorder.</div>
              {reportReasons.length === 0 && <span className="muted">No reasons yet.</span>}
              {reportReasons.map((reason, index) => (
                <div
                  key={reason}
                  className="chip-row"
                  draggable
                  onDragStart={(e) => e.dataTransfer.setData('text/plain', String(index))}
                  onDragOver={(e) => e.preventDefault()}
                  onDrop={(e) => {
                    const from = Number(e.dataTransfer.getData('text/plain'));
                    moveReason(from, index);
                  }}
                >
                  <div className="chip-label">
                    <span className="drag-handle">⋮⋮</span>
                    <span>{reason}</span>
                  </div>
                  <div className="chip-actions">
                    <button
                      className="ghost"
                      onClick={() => moveReason(index, Math.max(0, index - 1))}
                      disabled={index === 0}
                    >
                      Up
                    </button>
                    <button
                      className="ghost"
                      onClick={() => moveReason(index, Math.min(reportReasons.length - 1, index + 1))}
                      disabled={index === reportReasons.length - 1}
                    >
                      Down
                    </button>
                    <button
                      className="ghost danger"
                      onClick={() => saveReasons(reportReasons.filter((r) => r !== reason))}
                    >
                      Disable
                    </button>
                  </div>
                </div>
              ))}
            </div>
            <div className="report-reasons-column">
              <div className="section-title">Presets</div>
              <div className="section-subtitle">Tap to enable or disable.</div>
              <div className="pill-group presets">
                {reasonPresets.map((reason) => (
                  <button
                    key={reason}
                    className={`pill ${reportReasons.includes(reason) ? 'pill--active' : ''}`}
                    onClick={() => toggleReason(reason)}
                  >
                    {reason}
                  </button>
                ))}
              </div>
              <div className="section-title" style={{ marginTop: 16 }}>Add custom reason</div>
              <div className="reason-input-row">
                <input
                  className="input"
                  placeholder="Type a custom reason"
                  value={reasonInput}
                  onChange={(e) => setReasonInput(e.target.value)}
                />
                <button
                  className="primary"
                  onClick={() => {
                    const trimmed = reasonInput.trim();
                    if (!trimmed) return;
                    if (reportReasons.includes(trimmed)) {
                      setReasonInput('');
                      return;
                    }
                    const next = [...reportReasons, trimmed];
                    setReasonInput('');
                    saveReasons(next);
                  }}
                >
                  Add
                </button>
              </div>
            </div>
          </div>
        </div>
      <div className="grid-2 reports-grid">
        <div className="card reports-card reports-card--soft">
          <div className="card-header">
            <div>
              <h3><span className="section-icon section-icon--sla" />Resolution SLA</h3>
              <p>Time to resolve reports.</p>
            </div>
          </div>
          <div className="chart reports-chart">
            <Bar data={slaChart} options={{ responsive: true, plugins: { legend: { position: 'bottom' } } }} />
          </div>
        </div>
        <div className="card reports-card reports-card--soft">
          <div className="card-header">
            <div>
              <h3><span className="section-icon section-icon--institutions" />Institution breakdown</h3>
              <p>Top institutions by report volume.</p>
            </div>
          </div>
          <div className="chart reports-chart">
            <Bar data={institutionChart} options={{ responsive: true, plugins: { legend: { display: false } } }} />
          </div>
        </div>
      </div>
      <div className="card reports-card reports-card--soft">
        <div className="card-header">
          <div>
            <h3><span className="section-icon section-icon--trend" />Report volume trend</h3>
            <p>Activity for the selected range.</p>
          </div>
        </div>
        <div className="chart reports-chart">
          <Line data={trendChart} options={{ responsive: true, plugins: { legend: { position: 'bottom' } } }} />
        </div>
      </div>
      <div className="card reports-card">
        <div className="card-header">
          <div>
            <h3><span className="section-icon section-icon--latest" />Latest reports</h3>
            <p>Most recent 10 reports across the platform.</p>
          </div>
          <div className="panel-actions reports-actions">
            <button className="ghost" onClick={() => exportCsv(latestRows, 'latest-reports.csv')}>Export CSV</button>
            <button className="ghost" onClick={() => exportPdf({ type: 'all', filename: 'latest-reports.pdf' })}>Export PDF</button>
          </div>
        </div>
        <div className="table table--wide reports-table">
          <div className="table-row table-row--head">
            <div>Type</div>
            <div>Reporter</div>
            <div>Subject</div>
            <div>Reason</div>
            <div>Status</div>
            <div>Date</div>
          </div>
          {latestRows.length === 0 ? (
            <div className="table-row"><div>No reports found.</div></div>
          ) : (
            latestRows.map((row) => {
              const isPost = row._type === 'post';
              const subject = isPost ? row.post?.user : row.reported_user;
              return (
                <div className="table-row" key={`${row._type}-${row.id}`}>
                  <div>{isPost ? 'Post' : 'User'}</div>
                  <div>{row.reporter?.name || '-'}</div>
                  <div>{subject?.name || '-'}</div>
                  <div>{row.reason || '-'}</div>
                  <div><StatusPill status={row.status} /></div>
                  <div>{row.created_at ? new Date(row.created_at).toLocaleDateString() : '-'}</div>
                </div>
              );
            })
          )}
        </div>
      </div>
      <div className="card reports-card">
        <div className="card-header">
          <div>
            <h3><span className="section-icon section-icon--table" />Reports table</h3>
            <p>Browse all reports with filters.</p>
          </div>
          <div className="panel-actions reports-actions">
            <button className="ghost" onClick={() => exportCsv(rows, 'reports-table.csv')} disabled={!rows.length}>Export CSV</button>
            <button className="ghost" onClick={() => exportPdf({ type: typeFilter, filename: 'reports-table.pdf' })}>Export PDF</button>
          </div>
        </div>
        <div className="reports-filters-wrap">
          <div className="card-form reports-filters">
            <select className="select" value={typeFilter} onChange={(e) => { setTypeFilter(e.target.value); setPage(1); }}>
              <option value="posts">Post reports</option>
              <option value="users">User reports</option>
            </select>
            <select className="select" value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}>
              <option value="">All statuses</option>
              <option value="pending">Pending</option>
              <option value="resolved">Resolved</option>
              <option value="dismissed">Dismissed</option>
            </select>
            <input
              className="input"
              placeholder="Search by reason or name"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setPage(1);
              }}
            />
          </div>
        </div>
        <div className="table table--wide reports-table">
          <div className="table-row table-row--head">
            <div>Reporter</div>
            <div>{typeFilter === 'posts' ? 'Post Author' : 'Reported user'}</div>
            <div>Reason</div>
            <div>Status</div>
            <div>Date</div>
          </div>
          {tableLoading ? (
            <div className="table-row"><div>Loading...</div></div>
          ) : rows.length === 0 ? (
            <div className="table-row"><div>No reports found.</div></div>
          ) : (
            rows.map((row) => {
              const subject = typeFilter === 'posts' ? row.post?.user : row.reported_user;
              return (
                <div
                  className="table-row table-row--clickable"
                  key={`${typeFilter}-${row.id}`}
                  onClick={() => setDetailState({ open: true, report: row, type: typeFilter === 'posts' ? 'post' : 'user' })}
                >
                  <div>{row.reporter?.name || '-'}</div>
                  <div>{subject?.name || '-'}</div>
                  <div>{row.reason || '-'}</div>
                  <div><StatusPill status={row.status} /></div>
                  <div>{row.created_at ? new Date(row.created_at).toLocaleDateString() : '-'}</div>
                </div>
              );
            })
          )}
        </div>
        <div className="pagination">
          <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
          <span>Page {page}</span>
          <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
        </div>
      </div>
      {detailState.open && detailState.report && (
        <div className="modal-backdrop" onClick={() => setDetailState({ open: false, report: null, type: 'post' })}>
          <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">Report details</div>
            <div className="modal-message">
              <div className="detail-grid">
                <div><strong>Type</strong><span>{detailState.type === 'post' ? 'Post report' : 'User report'}</span></div>
                <div><strong>Status</strong><span>{detailState.report.status}</span></div>
                <div><strong>Reporter</strong><span>{detailState.report.reporter?.name || '-'}</span></div>
                <div><strong>Reason</strong><span>{detailState.report.reason || '-'}</span></div>
                <div><strong>Created</strong><span>{detailState.report.created_at ? new Date(detailState.report.created_at).toLocaleString() : '-'}</span></div>
                <div>
                  <strong>Subject</strong>
                  <span>
                    {detailState.type === 'post'
                      ? (detailState.report.post?.user?.name || '-')
                      : (detailState.report.reported_user?.name || '-')}
                  </span>
                </div>
              </div>
              {detailState.type === 'post' && (
                <div className="card" style={{ marginTop: 12 }}>
                  <div className="card-header">
                    <div>
                      <h3>Post snapshot</h3>
                    </div>
                  </div>
                  <div className="card-form">
                    <div>{detailState.report.post?.content || 'No content'}</div>
                  </div>
                </div>
              )}
            </div>
            <div className="modal-actions">
              <button
                className="ghost"
                onClick={() => navigate(detailState.type === 'post' ? '/super/moderation/posts' : '/super/moderation/users')}
              >
                Open in moderation
              </button>
              <button className="ghost" onClick={() => setDetailState({ open: false, report: null, type: 'post' })}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function VerificationView({ institutionId, scopeLabel }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('pending');
  const [profileUser, setProfileUser] = useState(null);
  const [profileData, setProfileData] = useState(null);
  const [confirmState, setConfirmState] = useState({ open: false });

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchVerificationRequests({
        status,
        institutionId,
        page,
        perPage: 20,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load verification requests');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [status, page, institutionId]);

  async function openProfile(user) {
    if (!user?.id) return;
    setProfileUser(user);
    try {
      const data = await fetchUserProfile(user.id);
      const fetchedUser = data?.user || data || null;
      setProfileUser(fetchedUser || user);
      setProfileData(fetchedUser || null);
    } catch (_) {
      setProfileData(null);
    }
  }

  function applyRowUpdate(rowId, nextStatus) {
    setRows((prev) => {
      if (status === 'pending') {
        return prev.filter((r) => r.id !== rowId);
      }
      return prev.map((r) => (r.id === rowId ? { ...r, verification_status: nextStatus } : r));
    });
  }

  function confirmAction(action, row) {
    const userId = row?.user?.id;
    if (!userId) return;
    setConfirmState({
      open: true,
      title: action === 'verify' ? 'Approve verification' : 'Reject verification',
      message:
        action === 'verify'
          ? `Approve verification for ${row.user?.name || 'this user'}?`
          : `Reject verification for ${row.user?.name || 'this user'}?`,
      confirmLabel: action === 'verify' ? 'Approve' : 'Reject',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          if (action === 'verify') {
            await verifyProfile(userId);
            applyRowUpdate(row.id, 'verified');
          } else {
            const reason = window.prompt('Optional rejection reason') || null;
            await rejectProfile(userId, reason);
            applyRowUpdate(row.id, 'rejected');
          }
        } catch (err) {
          setError(err.message || 'Failed to update verification');
        }
      },
    });
  }

  function exportCsv() {
    if (!rows.length) return;
    const headers = ['id', 'name', 'email', 'institution', 'status', 'requested_at'];
    const lines = rows.map((row) => {
      const name = row.user?.name || '';
      const email = row.user?.email || '';
      const institution = row.user?.institution?.name || '';
      const statusVal = row.verification_status || '';
      const requestedAt = row.requested_at || '';
      return [row.id, name, email, institution, statusVal, requestedAt]
        .map((v) => `"${String(v).replace(/"/g, '""')}"`)
        .join(',');
    });
    const csv = [headers.join(','), ...lines].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'verification-requests.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Verification requests</h2>
          <p>Review alumni profile verification submissions.</p>
        </div>
        <div className="panel-actions">
          <select className="select" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
            <option value="pending">Pending</option>
            <option value="verified">Verified</option>
            <option value="rejected">Rejected</option>
            <option value="unverified">Unverified</option>
          </select>
          <button className="ghost" onClick={exportCsv} disabled={!rows.length}>Export CSV</button>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      {error && <div className="alert">{error}</div>}
      <div className="table table--wide support-table-section support-table--head-centered">
        <div className="table-row table-row--head">
          <div>Name</div>
          <div>Email</div>
          <div>Institution</div>
          <div>Graduation</div>
          <div>Program</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No verification requests found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div className="link" onClick={() => openProfile(row.user)}>{row.user?.name || '-'}</div>
              <div>{row.user?.email || '-'}</div>
              <div>{row.user?.institution?.name || '-'}</div>
              <div>{row.profile?.graduation_year || '-'}</div>
              <div>{row.profile?.program || row.profile?.department || '-'}</div>
              <div><StatusPill status={row.verification_status} /></div>
              <div className="actions">
                <button className="ghost" onClick={() => openProfile(row.user)}>View profile</button>
                <button className="ghost" onClick={() => confirmAction('verify', row)}>Approve</button>
                <button className="ghost danger" onClick={() => confirmAction('reject', row)}>Reject</button>
              </div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
      <UserProfileModal
        open={!!profileUser}
        user={profileUser}
        profile={profileData?.profile}
        onClose={() => { setProfileUser(null); setProfileData(null); }}
        onSaved={() => { setProfileUser(null); setProfileData(null); }}
      />
    </div>
  );
}

function TransactionsView({
  institutionId,
  scopeLabel,
  portalMode = 'admin',
  initialFilters = null,
  headingOverride = '',
  subtitleOverride = '',
}) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [feeEnabled, setFeeEnabled] = useState(true);
  const [receiptState, setReceiptState] = useState({ open: false, url: null });
  const [backfillState, setBackfillState] = useState({ open: false, force: false });
  const [backfillStatus, setBackfillStatus] = useState('');
  const [backfillRunning, setBackfillRunning] = useState(false);
  const [filters, setFilters] = useState({
    status: '',
    type: '',
    provider: '',
    currency: '',
    search: '',
    from: '',
    to: '',
    ...(initialFilters || {}),
  });
  const [confirmState, setConfirmState] = useState({ open: false });
  const [refundState, setRefundState] = useState({ open: false, transaction: null });
  const [detailState, setDetailState] = useState({ open: false, transaction: null });
  const summary = useMemo(() => {
    if (!rows.length) return null;
    return rows.reduce(
      (acc, row) => {
        const meta = parseMetadata(row.metadata);
        const fee = Number(meta?.platform_fee_amount ?? 0);
        const net = Number(meta?.net_amount ?? (Number(row.amount ?? 0) - fee));
        acc.total += Number(row.amount ?? 0);
        acc.fee += fee;
        acc.net += net;
        acc.currency = row.currency || acc.currency;
        return acc;
      },
      { total: 0, fee: 0, net: 0, currency: rows[0]?.currency || 'GHS' }
    );
  }, [rows]);
  const receiptReadyCount = useMemo(
    () => rows.filter((row) => Boolean(row?.receipt_url)).length,
    [rows]
  );
  const pendingCount = useMemo(
    () => rows.filter((row) => (row?.status || '').toString() === 'pending').length,
    [rows]
  );
  const donationCount = useMemo(
    () => rows.filter((row) => (row?.type || '').toString() === 'donation').length,
    [rows]
  );
  const refundedCount = useMemo(
    () => rows.filter((row) => (row?.status || '').toString() === 'refunded').length,
    [rows]
  );

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchTransactions({
        ...filters,
        institutionId,
        page,
        perPage: 20,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load transactions');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [page, institutionId, filters.status, filters.type, filters.provider, filters.currency, filters.search, filters.from, filters.to]);

  useEffect(() => {
    fetchSystemSettings()
      .then((data) => {
        const list = data?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        setFeeEnabled(map.platform_fee_enabled !== false);
      })
      .catch(() => {});
  }, []);

  function confirmRefund(transaction) {
    setRefundState({ open: true, transaction });
  }

  const heading = headingOverride || (portalMode === 'accounting' ? 'Accounting Dashboard' : 'Payments');
  const subtitle = subtitleOverride || (portalMode === 'accounting'
    ? 'Monitor alumni payments, donation receipts, refunds, and platform revenue from one place.'
    : 'Track payment records, receipts, and transaction history.');

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>{heading}</h2>
          <p>{subtitle}</p>
        </div>
        <div className="panel-actions">
          {summary && (
            <div className="pill-group">
              <span className="pill">Total {formatCurrency(summary.currency, summary.total.toFixed(2))}</span>
              <span className="pill">Fees {formatCurrency(summary.currency, summary.fee.toFixed(2))}</span>
              <span className="pill">Net {formatCurrency(summary.currency, summary.net.toFixed(2))}</span>
              <span className="pill">Fee rate {summary.total > 0 ? `${((summary.fee / summary.total) * 100).toFixed(2)}%` : '0.00%'}</span>
            </div>
          )}
          <span className="pill">{feeEnabled ? 'Fee enabled' : 'Fee disabled'}</span>
          {backfillRunning && <span className="muted">Backfilling receipts…</span>}
          <button className="ghost" onClick={() => setBackfillState({ open: true, force: false })}>Backfill receipts</button>
          <button className="ghost" onClick={() => setBackfillState({ open: true, force: true })}>Backfill all</button>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      <div className="card">
        <div className="detail-grid">
          <div><strong>Receipt coverage</strong><span>{receiptReadyCount} ready</span></div>
          <div><strong>Receipts missing</strong><span>{Math.max(rows.length - receiptReadyCount, 0)}</span></div>
          <div><strong>Pending rows</strong><span>{pendingCount}</span></div>
          <div><strong>Donations</strong><span>{donationCount}</span></div>
          <div><strong>Refunded</strong><span>{refundedCount}</span></div>
          <div><strong>Fee %</strong><span>{summary && summary.total > 0 ? `${((summary.fee / summary.total) * 100).toFixed(2)}%` : '0.00%'}</span></div>
        </div>
      </div>
      <div className="card-form">
        <input className="input" placeholder="Search reference" value={filters.search} onChange={(e) => setFilters({ ...filters, search: e.target.value })} />
        <select className="select" value={filters.status} onChange={(e) => setFilters({ ...filters, status: e.target.value })}>
          <option value="">All statuses</option>
          <option value="success">Success</option>
          <option value="pending">Pending</option>
          <option value="failed">Failed</option>
          <option value="refunded">Refunded</option>
        </select>
        <select className="select" value={filters.type} onChange={(e) => setFilters({ ...filters, type: e.target.value })}>
          <option value="">All types</option>
          <option value="donation">Donation</option>
          <option value="event_ticket">Event ticket</option>
          <option value="membership_fee">Membership fee</option>
          <option value="subscription">Subscription</option>
          <option value="refund">Refund</option>
        </select>
        <select className="select" value={filters.provider} onChange={(e) => setFilters({ ...filters, provider: e.target.value })}>
          <option value="">All providers</option>
          <option value="stripe">Stripe</option>
          <option value="paystack">Paystack</option>
          <option value="flutterwave">Flutterwave</option>
        </select>
        <input className="input" placeholder="Currency" value={filters.currency} onChange={(e) => setFilters({ ...filters, currency: e.target.value })} />
        <input className="input" type="date" value={filters.from} onChange={(e) => setFilters({ ...filters, from: e.target.value })} />
        <input className="input" type="date" value={filters.to} onChange={(e) => setFilters({ ...filters, to: e.target.value })} />
      </div>
      {error && <div className="alert">{error}</div>}
      {backfillStatus && <div className="alert">{backfillStatus}</div>}
      <div className="table table--wide">
        <div className="table-row table-row--head">
          <div>Reference</div>
          <div>User</div>
          <div>Type</div>
          <div>Provider</div>
          <div>Amount</div>
          <div>Fee</div>
          <div>Net</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No transactions found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              {(() => {
                const meta = parseMetadata(row.metadata);
                const feeAmount = meta?.platform_fee_amount;
                const netAmount = meta?.net_amount;
                const feePercent = meta?.platform_fee_percent;
                const donationTransactionId = meta?.donation_transaction_id;
                const feeTitle = feePercent !== undefined && feePercent !== null
                  ? `Fee ${feePercent}%${donationTransactionId ? ` • Donation txn ${donationTransactionId}` : ''}`
                  : donationTransactionId
                    ? `Donation txn ${donationTransactionId}`
                    : '';
                return (
                  <>
              <div>{row.reference || '-'}</div>
              <div>{row.user?.name || '-'}</div>
              <div>{row.type}</div>
              <div>{row.provider}</div>
              <div>{formatCurrency(row.currency, row.amount)}</div>
              <div title={feeTitle}>
                {feeAmount !== undefined && feeAmount !== null ? formatCurrency(row.currency, feeAmount) : '-'}
                {feeTitle ? <span className="hint" style={{ marginLeft: 6 }}>ⓘ</span> : null}
              </div>
              <div title={feeTitle}>
                {netAmount !== undefined && netAmount !== null ? formatCurrency(row.currency, netAmount) : '-'}
              </div>
              <div><StatusPill status={row.status} /></div>
              <div className="actions">
                <button className="ghost" onClick={() => setDetailState({ open: true, transaction: row })}>
                  Details
                </button>
                {row.receipt_url ? (
                  <button className="ghost" onClick={() => setReceiptState({ open: true, url: row.receipt_url })}>
                    Receipt
                  </button>
                ) : (
                  <button
                    className="ghost"
                    disabled={!['success', 'refunded'].includes((row?.status || '').toString())}
                    title={!['success', 'refunded'].includes((row?.status || '').toString()) ? 'Receipts can only be generated after payment succeeds or is refunded.' : 'Generate receipt'}
                    onClick={async () => {
                      if (!['success', 'refunded'].includes((row?.status || '').toString())) return;
                      try {
                        const res = await generateTransactionReceipt(row.id);
                        const updated = res?.transaction;
                        if (updated) {
                          setRows((prev) => prev.map((item) => (item.id === row.id ? updated : item)));
                          if (updated.receipt_url) {
                            setReceiptState({ open: true, url: updated.receipt_url });
                          }
                        }
                      } catch (err) {
                        setError(err.message || 'Failed to generate receipt');
                      }
                    }}
                  >
                    Generate receipt
                  </button>
                )}
                {row.status === 'success' && row.type !== 'refund' && (
                  <button className="ghost" onClick={() => confirmRefund(row)}>Refund</button>
                )}
              </div>
                  </>
                );
              })()}
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
      <ConfirmModal
        open={backfillState.open}
        title="Backfill receipts"
        message={backfillState.force
          ? 'Regenerate receipts for all transactions (even if a receipt already exists). This may take a few minutes.'
          : 'Generate receipts for transactions missing a receipt. This may take a few minutes.'}
        confirmLabel={backfillState.force ? 'Backfill all' : 'Start backfill'}
        onCancel={() => setBackfillState({ open: false, force: false })}
        onConfirm={async () => {
          const force = backfillState.force;
          setBackfillState({ open: false, force: false });
          setBackfillRunning(true);
          setError('');
          setBackfillStatus('');
          try {
            const res = await backfillReceipts({ limit: 500, force });
            const message = `Backfill complete: ${res?.generated ?? 0} generated, ${res?.failed ?? 0} failed.`;
            setBackfillStatus(message);
            loadData();
          } catch (err) {
            setError(err.message || 'Failed to backfill receipts');
          } finally {
            setBackfillRunning(false);
          }
        }}
      />
      <RefundModal
        open={refundState.open}
        transaction={refundState.transaction}
        onCancel={() => setRefundState({ open: false, transaction: null })}
        onConfirm={async (transaction, payload) => {
          setRefundState({ open: false, transaction: null });
          try {
            await refundTransaction(transaction.id, payload);
            loadData();
          } catch (err) {
            setError(err.message || 'Refund failed');
          }
        }}
      />
      <TransactionDetailModal
        open={detailState.open}
        transaction={detailState.transaction}
        onClose={() => setDetailState({ open: false, transaction: null })}
      />
      <ReceiptModal
        open={receiptState.open}
        url={receiptState.url}
        onClose={() => setReceiptState({ open: false, url: null })}
      />
    </div>
  );
}

function SubscriptionsView({ institutionId, scopeLabel }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [filters, setFilters] = useState({ status: '', interval: '', provider: '', search: '' });
  const [confirmState, setConfirmState] = useState({ open: false });

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchSubscriptions({
        institutionId,
        page,
        perPage: 20,
        ...filters,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load subscriptions');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [page, institutionId, filters.status, filters.interval, filters.provider, filters.search]);

  function confirmCancel(subscription) {
    setConfirmState({
      open: true,
      title: 'Cancel subscription',
      message: `Cancel ${subscription.plan_name}?`,
      confirmLabel: 'Cancel',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await cancelSubscription(subscription.id);
          loadData();
        } catch (err) {
          setError(err.message || 'Failed to cancel subscription');
        }
      },
    });
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Subscriptions</h2>
          <p>Manage membership plans and renewals.</p>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      <div className="card-form">
        <input className="input" placeholder="Search plan or user" value={filters.search} onChange={(e) => setFilters({ ...filters, search: e.target.value })} />
        <select className="select" value={filters.status} onChange={(e) => setFilters({ ...filters, status: e.target.value })}>
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="cancelled">Cancelled</option>
        </select>
        <select className="select" value={filters.interval} onChange={(e) => setFilters({ ...filters, interval: e.target.value })}>
          <option value="">All intervals</option>
          <option value="monthly">Monthly</option>
          <option value="yearly">Yearly</option>
        </select>
        <select className="select" value={filters.provider} onChange={(e) => setFilters({ ...filters, provider: e.target.value })}>
          <option value="">All providers</option>
          <option value="stripe">Stripe</option>
          <option value="paystack">Paystack</option>
          <option value="flutterwave">Flutterwave</option>
        </select>
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="table">
        <div className="table-row table-row--head">
          <div>User</div>
          <div>Plan</div>
          <div>Interval</div>
          <div>Amount</div>
          <div>Status</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No subscriptions found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div>{row.user?.name || '-'}</div>
              <div>{row.plan_name}</div>
              <div>{row.interval}</div>
              <div>{formatCurrency(row.currency, row.amount)}</div>
              <div><StatusPill status={row.status} /></div>
              <div className="actions">
                {row.status === 'active' && (
                  <button className="ghost" onClick={() => confirmCancel(row)}>Cancel</button>
                )}
              </div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
    </div>
  );
}

function CreateAdCard({ onCreated, institutions = [], showInstitutionTarget = false }) {
  const [form, setForm] = useState({
    title: '',
    placement: 'feed',
    pricing_model: 'cpc',
    objective: 'traffic',
    price: '',
    budget: '',
    currency: 'GHS',
    daily_cap_enabled: false,
    daily_budget: '',
    content: '',
    media_url: '',
    target_url: '',
    target_location: '',
    target_interests: '',
    target_institution_id: '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.title.trim() || !form.price || !form.budget) return;
    setLoading(true);
    setError('');
    try {
      await createAd({
        title: form.title.trim(),
        placement: form.placement,
        pricing_model: form.pricing_model,
        objective: form.objective,
        price: Number(form.price),
        budget: Number(form.budget),
        currency: form.currency.trim().toUpperCase(),
        daily_cap_enabled: form.daily_cap_enabled,
        daily_budget: form.daily_cap_enabled && form.daily_budget ? Number(form.daily_budget) : null,
        content: form.content || null,
        media_url: form.media_url || null,
        target_url: form.target_url || null,
        target_location: form.target_location || null,
        target_institution_id: form.target_institution_id ? Number(form.target_institution_id) : null,
        target_interests: form.target_interests
          ? form.target_interests.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
      });
      setForm({
        title: '',
        placement: 'feed',
        pricing_model: 'cpc',
        objective: 'traffic',
        price: '',
        budget: '',
        currency: 'GHS',
        daily_cap_enabled: false,
        daily_budget: '',
        content: '',
        media_url: '',
        target_url: '',
        target_location: '',
        target_interests: '',
        target_institution_id: '',
      });
      onCreated?.();
    } catch (err) {
      setError(err.message || 'Failed to create ad');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h3>Create ad campaign</h3>
      <p>Launch promotions across feeds, stories, and banners.</p>
      {error && <div className="alert">{error}</div>}
      <form className="card-form card-form--wide ads-form" onSubmit={handleSubmit}>
        <input className="input" placeholder="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        <select className="select" value={form.placement} onChange={(e) => setForm({ ...form, placement: e.target.value })}>
          <option value="feed">Feed</option>
          <option value="story">Story</option>
          <option value="banner">Banner</option>
        </select>
        <select
          className="select"
          value={form.objective}
          onChange={(e) => {
            const next = e.target.value;
            setForm({
              ...form,
              objective: next,
              pricing_model: AD_OBJECTIVE_PRICING[next] || form.pricing_model,
            });
          }}
        >
          {AD_OBJECTIVES.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
        <select className="select" value={form.pricing_model} onChange={(e) => setForm({ ...form, pricing_model: e.target.value })}>
          <option value="cpc">CPC</option>
          <option value="cpm">CPM</option>
          <option value="flat">Flat</option>
        </select>
        <input className="input" placeholder="Price" type="number" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
        <input className="input" placeholder="Budget" type="number" value={form.budget} onChange={(e) => setForm({ ...form, budget: e.target.value })} />
        <input className="input" placeholder="Currency" value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value })} />
        <label className="checkbox">
          <input
            type="checkbox"
            checked={form.daily_cap_enabled}
            onChange={(e) => setForm({ ...form, daily_cap_enabled: e.target.checked })}
          />
          Enable daily spend cap
        </label>
        {form.daily_cap_enabled && (
          <input
            className="input"
            placeholder="Daily budget"
            type="number"
            value={form.daily_budget}
            onChange={(e) => setForm({ ...form, daily_budget: e.target.value })}
          />
        )}
        {showInstitutionTarget && (
          <select
            className="select"
            value={form.target_institution_id}
            onChange={(e) => setForm({ ...form, target_institution_id: e.target.value })}
          >
            <option value="">Target all institutions</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <input className="input" placeholder="Target location" value={form.target_location} onChange={(e) => setForm({ ...form, target_location: e.target.value })} />
        <input className="input" placeholder="Target interests (comma)" value={form.target_interests} onChange={(e) => setForm({ ...form, target_interests: e.target.value })} />
        <input className="input" placeholder="Media URL" value={form.media_url} onChange={(e) => setForm({ ...form, media_url: e.target.value })} />
        <input className="input" placeholder="Target URL" value={form.target_url} onChange={(e) => setForm({ ...form, target_url: e.target.value })} />
        <textarea className="input" rows="2" placeholder="Content copy" value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} />
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Creating...' : 'Create ad'}
        </button>
      </form>
    </div>
  );
}

function EditAdCard({ ad, onSaved, onCancel, institutions = [], showInstitutionTarget = false }) {
  const [form, setForm] = useState({
    title: ad?.title || '',
    placement: ad?.placement || 'feed',
    pricing_model: ad?.pricing_model || 'cpc',
    objective: ad?.objective || 'traffic',
    price: ad?.price || '',
    budget: ad?.budget || '',
    currency: ad?.currency || 'GHS',
    daily_cap_enabled: !!ad?.daily_cap_enabled,
    daily_budget: ad?.daily_budget || '',
    content: ad?.content || '',
    media_url: ad?.media_url || '',
    target_url: ad?.target_url || '',
    target_location: ad?.target_location || '',
    target_interests: ad?.target_interests ? ad.target_interests.join(', ') : '',
    status: ad?.status || 'active',
    target_institution_id: ad?.target_institution_id ? String(ad.target_institution_id) : '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await updateAd(ad.id, {
        title: form.title || null,
        placement: form.placement,
        pricing_model: form.pricing_model,
        objective: form.objective,
        price: form.price ? Number(form.price) : null,
        budget: form.budget ? Number(form.budget) : null,
        currency: form.currency ? form.currency.trim().toUpperCase() : null,
        daily_cap_enabled: form.daily_cap_enabled,
        daily_budget: form.daily_cap_enabled && form.daily_budget ? Number(form.daily_budget) : null,
        content: form.content || null,
        media_url: form.media_url || null,
        target_url: form.target_url || null,
        target_location: form.target_location || null,
        target_institution_id: form.target_institution_id ? Number(form.target_institution_id) : null,
        target_interests: form.target_interests
          ? form.target_interests.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
        status: form.status,
      });
      onSaved?.();
    } catch (err) {
      setError(err.message || 'Failed to update ad');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <div className="card-title-row">
        <div>
          <h3>Edit ad</h3>
          <p>Update targeting and delivery settings.</p>
        </div>
        <button className="ghost" onClick={onCancel}>Close</button>
      </div>
      {error && <div className="alert">{error}</div>}
      <form className="card-form card-form--wide ads-form" onSubmit={handleSubmit}>
        <input className="input" placeholder="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        <select className="select" value={form.placement} onChange={(e) => setForm({ ...form, placement: e.target.value })}>
          <option value="feed">Feed</option>
          <option value="story">Story</option>
          <option value="banner">Banner</option>
        </select>
        <select
          className="select"
          value={form.objective}
          onChange={(e) => {
            const next = e.target.value;
            setForm({
              ...form,
              objective: next,
              pricing_model: AD_OBJECTIVE_PRICING[next] || form.pricing_model,
            });
          }}
        >
          {AD_OBJECTIVES.map((opt) => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
        <select className="select" value={form.pricing_model} onChange={(e) => setForm({ ...form, pricing_model: e.target.value })}>
          <option value="cpc">CPC</option>
          <option value="cpm">CPM</option>
          <option value="flat">Flat</option>
        </select>
        <input className="input" placeholder="Price" type="number" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} />
        <input className="input" placeholder="Budget" type="number" value={form.budget} onChange={(e) => setForm({ ...form, budget: e.target.value })} />
        <input className="input" placeholder="Currency" value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value })} />
        <select className="select" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
          <option value="active">Active</option>
          <option value="paused">Paused</option>
          <option value="ended">Ended</option>
        </select>
        <label className="checkbox">
          <input
            type="checkbox"
            checked={form.daily_cap_enabled}
            onChange={(e) => setForm({ ...form, daily_cap_enabled: e.target.checked })}
          />
          Enable daily spend cap
        </label>
        {form.daily_cap_enabled && (
          <input
            className="input"
            placeholder="Daily budget"
            type="number"
            value={form.daily_budget}
            onChange={(e) => setForm({ ...form, daily_budget: e.target.value })}
          />
        )}
        {showInstitutionTarget && (
          <select
            className="select"
            value={form.target_institution_id}
            onChange={(e) => setForm({ ...form, target_institution_id: e.target.value })}
          >
            <option value="">Target all institutions</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
        <input className="input" placeholder="Target location" value={form.target_location} onChange={(e) => setForm({ ...form, target_location: e.target.value })} />
        <input className="input" placeholder="Target interests (comma)" value={form.target_interests} onChange={(e) => setForm({ ...form, target_interests: e.target.value })} />
        <input className="input" placeholder="Media URL" value={form.media_url} onChange={(e) => setForm({ ...form, media_url: e.target.value })} />
        <input className="input" placeholder="Target URL" value={form.target_url} onChange={(e) => setForm({ ...form, target_url: e.target.value })} />
        <textarea className="input" rows="2" placeholder="Content copy" value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} />
        <button className="primary" type="submit" disabled={loading}>
          {loading ? 'Saving...' : 'Save'}
        </button>
      </form>
    </div>
  );
}

function AdsView({ scopeLabel, institutions = [], isSuper = false }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState(null);
  const [filters, setFilters] = useState({ status: '', placement: '', search: '' });
  const [confirmState, setConfirmState] = useState({ open: false });
  const [institutionFilter, setInstitutionFilter] = useState('');
  const [analytics, setAnalytics] = useState(null);
  const [analyticsLoading, setAnalyticsLoading] = useState(false);
  const [analyticsError, setAnalyticsError] = useState('');
  const [adAnalyticsOpen, setAdAnalyticsOpen] = useState(false);
  const [adAnalyticsLoading, setAdAnalyticsLoading] = useState(false);
  const [adAnalyticsError, setAdAnalyticsError] = useState('');
  const [adAnalytics, setAdAnalytics] = useState(null);
  const [adAnalyticsTarget, setAdAnalyticsTarget] = useState(null);
  const [adRange, setAdRange] = useState(() => {
    const to = new Date();
    const from = new Date();
    from.setDate(to.getDate() - 14);
    return { from: toDateInput(from), to: toDateInput(to) };
  });
  const [range, setRange] = useState(() => {
    const to = new Date();
    const from = new Date();
    from.setDate(to.getDate() - 30);
    return { from: toDateInput(from), to: toDateInput(to) };
  });

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchAds({
        ...filters,
        page,
        perPage: 20,
        institutionId: isSuper && institutionFilter ? institutionFilter : undefined,
      });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load ads');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [page, filters.status, filters.placement, filters.search, institutionFilter]);

  const loadAnalytics = async () => {
    setAnalyticsLoading(true);
    setAnalyticsError('');
    try {
      const data = await fetchAdsAnalytics({
        from: range.from,
        to: range.to,
        status: filters.status || undefined,
        placement: filters.placement || undefined,
        institutionId: isSuper && institutionFilter ? institutionFilter : undefined,
      });
      setAnalytics(data || null);
    } catch (err) {
      setAnalyticsError(err.message || 'Failed to load analytics');
    } finally {
      setAnalyticsLoading(false);
    }
  };

  useEffect(() => {
    loadAnalytics().catch(() => {});
  }, [range.from, range.to, filters.status, filters.placement, institutionFilter]);

  function confirmDelete(ad) {
    setConfirmState({
      open: true,
      title: 'Delete ad',
      message: `Delete "${ad.title}"?`,
      confirmLabel: 'Delete',
      onConfirm: async () => {
        setConfirmState({ open: false });
        try {
          await deleteAd(ad.id);
          setRows((prev) => prev.filter((row) => row.id !== ad.id));
        } catch (err) {
          setError(err.message || 'Failed to delete ad');
        }
      },
    });
  }

  async function openAdAnalytics(ad) {
    setAdAnalyticsTarget(ad);
    setAdAnalyticsOpen(true);
    setAdAnalyticsLoading(true);
    setAdAnalyticsError('');
    try {
      const data = await fetchAdAnalytics(ad.id, { from: adRange.from, to: adRange.to });
      setAdAnalytics(data || null);
    } catch (err) {
      setAdAnalyticsError(err.message || 'Failed to load analytics');
    } finally {
      setAdAnalyticsLoading(false);
    }
  }

  async function reloadAdAnalytics(nextRange) {
    if (!adAnalyticsTarget) return;
    setAdAnalyticsLoading(true);
    setAdAnalyticsError('');
    try {
      const data = await fetchAdAnalytics(adAnalyticsTarget.id, { from: nextRange.from, to: nextRange.to });
      setAdAnalytics(data || null);
    } catch (err) {
      setAdAnalyticsError(err.message || 'Failed to load analytics');
    } finally {
      setAdAnalyticsLoading(false);
    }
  }

  const series = analytics?.series || [];
  const maxSeriesValue = Math.max(
    ...series.map((item) => Math.max(item.impressions || 0, item.clicks || 0)),
    1
  );

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Ads & Monetization</h2>
          <p>Create and manage sponsored content campaigns.</p>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      <div className="card ads-analytics">
        <div className="card-title-row">
          <div>
            <h3>Campaign performance</h3>
            <p>Track impressions, clicks, CTR, and spend.</p>
          </div>
          <div className="ads-analytics-controls">
            <input
              className="input"
              type="date"
              value={range.from}
              onChange={(e) => setRange((prev) => ({ ...prev, from: e.target.value }))}
            />
            <input
              className="input"
              type="date"
              value={range.to}
              onChange={(e) => setRange((prev) => ({ ...prev, to: e.target.value }))}
            />
          </div>
        </div>
        {analyticsError && <div className="alert">{analyticsError}</div>}
        {analyticsLoading ? (
          <div className="muted">Loading analytics...</div>
        ) : (
          <>
            <div className="metrics-grid ads-metrics">
              <div className="metric">
                <div className="metric-title">Active ads</div>
                <div className="metric-value">{analytics?.summary?.ads_active ?? 0}</div>
                <div className="metric-subtitle">Out of {analytics?.summary?.ads_total ?? 0} campaigns</div>
              </div>
              <div className="metric">
                <div className="metric-title">Impressions</div>
                <div className="metric-value">{analytics?.summary?.impressions ?? 0}</div>
                <div className="metric-subtitle">Within selected range</div>
              </div>
              <div className="metric">
                <div className="metric-title">Clicks</div>
                <div className="metric-value">{analytics?.summary?.clicks ?? 0}</div>
                <div className="metric-subtitle">CTR {analytics?.summary?.ctr_percent ?? 0}%</div>
              </div>
              <div className="metric">
                <div className="metric-title">Spend</div>
                <div className="metric-value">{analytics?.summary?.spend_total ?? 0}</div>
                <div className="metric-subtitle">
                  {(analytics?.summary?.spend_by_currency
                    ? Object.entries(analytics.summary.spend_by_currency)
                        .map(([code, value]) => `${currencySymbol(code)} ${value}`)
                        .join(' · ')
                    : 'No spend yet')}
                </div>
              </div>
              <div className="metric">
                <div className="metric-title">Budget remaining</div>
                <div className="metric-value">{analytics?.summary?.budget_remaining ?? 0}</div>
                <div className="metric-subtitle">Total budget {analytics?.summary?.budget_total ?? 0}</div>
              </div>
            </div>
            <div className="ads-analytics-grid">
              <div className="ads-chart">
                <div className="ads-chart-header">
                  <strong>Engagement trend</strong>
                  <span>{analytics?.range?.from} → {analytics?.range?.to}</span>
                </div>
                <div className="ads-chart-bars">
                  {series.map((item) => {
                    const impressionsHeight = Math.round(((item.impressions || 0) / maxSeriesValue) * 100);
                    const clicksHeight = Math.round(((item.clicks || 0) / maxSeriesValue) * 100);
                    return (
                      <div key={item.date} className="ads-chart-bar">
                        <span className="bar impressions" style={{ height: `${impressionsHeight}%` }} />
                        <span className="bar clicks" style={{ height: `${clicksHeight}%` }} />
                        <em>{item.date.slice(5)}</em>
                      </div>
                    );
                  })}
                </div>
              </div>
              <div className="ads-breakdown">
                <div>
                  <strong>Placements</strong>
                  <div className="ads-pill-row">
                    {Object.entries(analytics?.breakdowns?.placements || {}).length === 0 && <span className="muted">No placements yet</span>}
                    {Object.entries(analytics?.breakdowns?.placements || {}).map(([key, value]) => (
                      <span key={key} className="pill">{key} · {value}</span>
                    ))}
                  </div>
                </div>
                <div>
                  <strong>Pricing models</strong>
                  <div className="ads-pill-row">
                    {Object.entries(analytics?.breakdowns?.pricing_models || {}).length === 0 && <span className="muted">No campaigns yet</span>}
                    {Object.entries(analytics?.breakdowns?.pricing_models || {}).map(([key, value]) => (
                      <span key={key} className="pill">{key} · {value}</span>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
      {editing ? (
        <EditAdCard
          ad={editing}
          onSaved={() => {
            setEditing(null);
            loadData();
          }}
          onCancel={() => setEditing(null)}
          institutions={institutions}
          showInstitutionTarget={isSuper}
        />
      ) : (
        <CreateAdCard onCreated={loadData} institutions={institutions} showInstitutionTarget={isSuper} />
      )}
      <div className="card-form">
        <input className="input" placeholder="Search ads" value={filters.search} onChange={(e) => setFilters({ ...filters, search: e.target.value })} />
        <select className="select" value={filters.status} onChange={(e) => setFilters({ ...filters, status: e.target.value })}>
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="paused">Paused</option>
          <option value="ended">Ended</option>
        </select>
        <select className="select" value={filters.placement} onChange={(e) => setFilters({ ...filters, placement: e.target.value })}>
          <option value="">All placements</option>
          <option value="feed">Feed</option>
          <option value="story">Story</option>
          <option value="banner">Banner</option>
        </select>
        {isSuper && (
          <select className="select" value={institutionFilter} onChange={(e) => {
            setInstitutionFilter(e.target.value);
            setPage(1);
          }}>
            <option value="">All institutions</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="table table--wide table--ads">
        <div className="table-row table-row--head">
          <div>Title</div>
          <div>Placement</div>
          <div>Status</div>
          <div>Pricing</div>
          <div>Targeting</div>
          <div>Budget</div>
          <div>Metrics</div>
          <div>Action</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No ads found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div className="title-cell">
                <strong>{row.title}</strong>
                <span>{row.content ? String(row.content).slice(0, 60) : 'Sponsored placement'}</span>
              </div>
              <div>{row.placement}</div>
              <div><StatusPill status={row.status} /></div>
              <div>
                <div>{row.objective || 'traffic'} · {row.pricing_model?.toUpperCase()} · {formatCurrency(row.currency, row.price)}</div>
                <div className="muted">Budget {formatCurrency(row.currency, row.budget)}</div>
                <div className="muted">
                  Daily cap {row.daily_cap_enabled ? formatCurrency(row.currency, row.daily_budget || 0) : 'Off'}
                </div>
              </div>
              <div className="ads-targeting">
                <div>
                  Institution: {row.target_institution_id ? (institutions.find((i) => i.id === Number(row.target_institution_id))?.name || row.target_institution_id) : 'All'}
                </div>
                <div>Location: {row.target_location || 'Any'}</div>
                <div>Interests: {(row.target_interests || []).slice(0, 2).join(', ') || 'Any'}</div>
              </div>
              <div>{formatCurrency(row.currency, row.budget)}</div>
              <div>
                <div>{row.metrics?.impressions || 0} impressions · {row.metrics?.clicks || 0} clicks</div>
                <div className="muted">CTR {row.metrics?.ctr_percent ?? 0}% · Spend {formatCurrency(row.currency, row.metrics?.spend ?? 0)}</div>
                {(row.metrics?.spend ?? 0) >= (row.budget ?? 0) && (
                  <span className="badge badge--danger">Budget exhausted</span>
                )}
              </div>
              <div className="actions">
                <button className="ghost" onClick={() => openAdAnalytics(row)}>Analytics</button>
                {row.status === 'active' ? (
                  <button
                    className="ghost"
                    onClick={() => updateAd(row.id, { status: 'paused' }).then(loadData).catch((err) => setError(err.message || 'Failed to pause ad'))}
                  >
                    Pause
                  </button>
                ) : row.status === 'paused' ? (
                  <button
                    className="ghost"
                    onClick={() => updateAd(row.id, { status: 'active' }).then(loadData).catch((err) => setError(err.message || 'Failed to resume ad'))}
                  >
                    Resume
                  </button>
                ) : null}
                <button className="ghost" onClick={() => setEditing(row)}>Edit</button>
                <button className="ghost danger" onClick={() => confirmDelete(row)}>Delete</button>
              </div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
      <ConfirmModal
        open={confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        confirmLabel={confirmState.confirmLabel}
        onCancel={() => setConfirmState({ open: false })}
        onConfirm={confirmState.onConfirm}
      />
      <AdAnalyticsModal
        open={adAnalyticsOpen}
        ad={adAnalyticsTarget}
        analytics={adAnalytics}
        loading={adAnalyticsLoading}
        error={adAnalyticsError}
        range={adRange}
        onRangeChange={(next) => {
          setAdRange(next);
          reloadAdAnalytics(next);
        }}
        onClose={() => {
          setAdAnalyticsOpen(false);
          setAdAnalyticsTarget(null);
          setAdAnalytics(null);
        }}
      />
    </div>
  );
}

function DirectorySearchView({ institutions = [], isSuper = false }) {
  const [mode, setMode] = useState('alumni');
  const [query, setQuery] = useState('');
  const [graduationYear, setGraduationYear] = useState('');
  const [industry, setIndustry] = useState('');
  const [loading, setLoading] = useState(false);
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [error, setError] = useState('');
  const [profileOpen, setProfileOpen] = useState(false);
  const [profileUser, setProfileUser] = useState(null);
  const [profileData, setProfileData] = useState(null);
  const [profileLoading, setProfileLoading] = useState(false);
  const [profileError, setProfileError] = useState('');
  const [institutionOpen, setInstitutionOpen] = useState(false);
  const [institutionData, setInstitutionData] = useState(null);
  const [institutionLoading, setInstitutionLoading] = useState(false);
  const [institutionError, setInstitutionError] = useState('');

  const loadData = async (reset = false) => {
    if (mode === 'schools' && !query.trim()) {
      setRows([]);
      setMeta(null);
      return;
    }
    if (mode === 'alumni' && !query.trim() && !graduationYear.trim() && !industry.trim()) {
      setRows([]);
      setMeta(null);
      return;
    }
    setLoading(true);
    setError('');
    try {
      if (mode === 'schools') {
        const data = await fetchInstitutionsSearch({ search: query });
        setRows(data?.data || []);
        setMeta(null);
      } else {
        const data = await fetchDirectoryUsers({
          q: query,
          graduationYear: graduationYear.trim() || undefined,
          industry: industry.trim() || undefined,
          page: reset ? 1 : page,
          perPage: 20,
        });
        setRows(data?.data || []);
        setMeta(data?.meta || null);
      }
    } catch (err) {
      setError(err.message || 'Failed to search directory');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData(true).catch(() => {});
  }, [mode]);

  useEffect(() => {
    if (mode === 'schools' && !query.trim()) return;
    if (mode === 'alumni' && !query.trim() && !graduationYear.trim() && !industry.trim()) return;
    loadData(true).catch(() => {});
  }, [page]);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Directory Search</h2>
          <p>Find alumni and institutions.</p>
        </div>
      </div>
      <div className="card-form">
        <input
          className="input"
          placeholder={mode === 'schools' ? 'Search schools' : 'Search alumni'}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setPage(1);
            if (mode === 'schools' && e.target.value.trim().length >= 2) {
              loadData(true).catch(() => {});
            } else if (mode === 'alumni' && (e.target.value.trim().length >= 2 || graduationYear.trim() || industry.trim())) {
              loadData(true).catch(() => {});
            } else {
              setRows([]);
              setMeta(null);
            }
          }}
        />
        <div className="chip-actions">
          <button className={`chip${mode === 'alumni' ? ' chip--active' : ''}`} onClick={() => setMode('alumni')}>
            Alumni
          </button>
          <button className={`chip${mode === 'schools' ? ' chip--active' : ''}`} onClick={() => setMode('schools')}>
            Schools
          </button>
        </div>
        {mode === 'alumni' ? (
          <div className="card-form card-form--wide" style={{ marginTop: 12 }}>
            <input
              className="input"
              placeholder="Graduation year"
              value={graduationYear}
              onChange={(e) => {
                setGraduationYear(e.target.value);
                setPage(1);
                if (query.trim() || e.target.value.trim() || industry.trim()) {
                  loadData(true).catch(() => {});
                } else {
                  setRows([]);
                  setMeta(null);
                }
              }}
            />
            <input
              className="input"
              placeholder="Industry"
              value={industry}
              onChange={(e) => {
                setIndustry(e.target.value);
                setPage(1);
                if (query.trim() || graduationYear.trim() || e.target.value.trim()) {
                  loadData(true).catch(() => {});
                } else {
                  setRows([]);
                  setMeta(null);
                }
              }}
            />
          </div>
        ) : null}
      </div>
      {error && <div className="alert">{error}</div>}
      {loading ? (
        <div className="card">Loading...</div>
      ) : rows.length === 0 ? (
        <div className="card">No results yet.</div>
      ) : (
        <div className="table table--wide">
          <div className="table-row table-row--head">
            <div>Name</div>
            <div>Details</div>
            <div>Action</div>
          </div>
          {rows.map((row) => {
            if (mode === 'schools') {
              return (
                <div className="table-row" key={`school-${row.id}`}>
                  <div className="title-cell">
                    <strong>{row.name}</strong>
                    <span>{row.slug}</span>
                  </div>
                  <div>Status: {row.status || 'active'}</div>
                  <div className="actions">
                    <button
                      className="ghost"
                      onClick={async () => {
                        setInstitutionOpen(true);
                        setInstitutionLoading(true);
                        setInstitutionError('');
                        try {
                          const res = await fetchInstitutionPublic(row.id);
                          setInstitutionData(res?.institution || null);
                        } catch (err) {
                          setInstitutionError(err.message || 'Failed to load institution profile');
                        } finally {
                          setInstitutionLoading(false);
                        }
                      }}
                    >
                      View
                    </button>
                  </div>
                </div>
              );
            }
            const program = row.program || row.department || '';
            const location = row.location || '';
            const rowIndustry = row.industry || '';
            return (
              <div className="table-row" key={`user-${row.id}`}>
                <div className="title-cell">
                  <strong>{row.name}</strong>
                  <span>{row.headline || 'Alumni'}</span>
                </div>
                <div>{[program, rowIndustry, location].filter(Boolean).join(' • ') || '—'}</div>
                <div className="actions">
                  <button
                    className="ghost"
                    onClick={async () => {
                      setProfileOpen(true);
                      setProfileLoading(true);
                      setProfileError('');
                      try {
                        const res = await fetchUserProfile(row.id);
                        setProfileUser(res?.user || null);
                        setProfileData(res?.profile || res?.user?.profile || null);
                      } catch (err) {
                        setProfileError(err.message || 'Failed to load user profile');
                      } finally {
                        setProfileLoading(false);
                      }
                    }}
                  >
                    {isSuper ? 'Edit' : 'View'}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
      {mode === 'alumni' && meta && (
        <div className="pagination">
          <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
          <span>Page {page}</span>
          <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={page >= (meta?.last_page || page)}>Next</button>
        </div>
      )}
      {profileError && <div className="alert">{profileError}</div>}
      {institutionError && <div className="alert">{institutionError}</div>}
      {isSuper ? (
        <UserProfileModal
          open={profileOpen}
          user={profileUser}
          profile={profileData}
          onClose={() => {
            setProfileOpen(false);
            setProfileUser(null);
            setProfileData(null);
            setProfileError('');
          }}
          onSaved={() => {
            setProfileOpen(false);
            setProfileUser(null);
            setProfileData(null);
          }}
        />
      ) : (
        <UserProfilePreviewModal
          open={profileOpen}
          user={profileUser}
          onClose={() => {
            setProfileOpen(false);
            setProfileUser(null);
            setProfileData(null);
            setProfileError('');
          }}
        />
      )}
      <InstitutionProfileModal
        open={institutionOpen}
        institution={institutionData}
        onClose={() => {
          setInstitutionOpen(false);
          setInstitutionData(null);
          setInstitutionError('');
        }}
      />
      {profileLoading && profileOpen && (
        <div className="modal-backdrop">
          <div className="modal">
            <div className="modal-title">Loading profile...</div>
          </div>
        </div>
      )}
      {institutionLoading && institutionOpen && (
        <div className="modal-backdrop">
          <div className="modal">
            <div className="modal-title">Loading institution...</div>
          </div>
        </div>
      )}
    </div>
  );
}

function AiControlsView() {
  const [controls, setControls] = useState(null);
  const [stats, setStats] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchAiControls()
      .then((data) => setControls(data?.data || null))
      .catch((err) => setError(err.message || 'Failed to load AI controls'));
    fetchAiPerformance()
      .then((data) => setStats(data?.stats || null))
      .catch(() => {});
  }, []);

  async function handleSave() {
    if (!controls) return;
    setSaving(true);
    setError('');
    try {
      const payload = {
        feed_personalization_enabled: !!controls.feed_personalization_enabled,
        recommendations_enabled: !!controls.recommendations_enabled,
        max_daily_recommendations: Number(controls.max_daily_recommendations || 0),
        guardrails: controls.guardrails || [],
      };
      const data = await updateAiControls(payload);
      setControls(data?.data || controls);
    } catch (err) {
      setError(err.message || 'Failed to update AI controls');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>AI Controls</h2>
          <p>Manage recommendations and personalization.</p>
        </div>
      </div>
      {error && <div className="alert">{error}</div>}
      {controls && (
        <div className="card-form">
          <label className="toggle">
            <input
              type="checkbox"
              checked={!!controls.feed_personalization_enabled}
              onChange={(e) => setControls({ ...controls, feed_personalization_enabled: e.target.checked })}
            />
            <span>Feed personalization enabled</span>
          </label>
          <label className="toggle">
            <input
              type="checkbox"
              checked={!!controls.recommendations_enabled}
              onChange={(e) => setControls({ ...controls, recommendations_enabled: e.target.checked })}
            />
            <span>Recommendations enabled</span>
          </label>
          <input
            className="input"
            type="number"
            placeholder="Max daily recommendations"
            value={controls.max_daily_recommendations || ''}
            onChange={(e) => setControls({ ...controls, max_daily_recommendations: e.target.value })}
          />
          <textarea
            className="input"
            rows="3"
            placeholder="Guardrails (comma separated)"
            value={controls.guardrails?.join(', ') || ''}
            onChange={(e) => setControls({ ...controls, guardrails: e.target.value.split(',').map((v) => v.trim()).filter(Boolean) })}
          />
          <div className="ai-controls-actions">
            <button className="primary btn-sm" onClick={handleSave} disabled={saving}>
              {saving ? 'Saving...' : 'Save controls'}
            </button>
          </div>
        </div>
      )}
      {stats && (
        <div className="card">
          <h3>AI Performance</h3>
          <p>
            {stats.recommendations_total || 0} recommendations,
            {' '}
            {stats.recommendations_served || 0} served,
            {' '}
            {stats.recommendations_clicked || 0} clicks,
            {' '}
            CTR {stats.ctr_percent || 0}%.
          </p>
          {stats.by_type && (
            <div className="table">
              <div className="table-row table-head">
                <div>Type</div>
                <div>Total</div>
                <div>Clicks</div>
                <div>CTR</div>
              </div>
              {Object.entries(stats.by_type).map(([type, row]) => (
                <div className="table-row" key={type}>
                  <div>{type}</div>
                  <div>{row.total ?? 0}</div>
                  <div>{row.clicked ?? 0}</div>
                  <div>{row.ctr ?? 0}%</div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function AuditLogsView({ currentUser }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [filters, setFilters] = useState({ action: '', entityType: '', actorId: '', from: '', to: '' });
  const [myOnly, setMyOnly] = useState(false);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const actorId = myOnly && currentUser?.id ? String(currentUser.id) : filters.actorId;
      const data = await fetchAuditLogs({ ...filters, actorId, page, perPage: 20 });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load audit logs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [page, filters.action, filters.entityType, filters.actorId, filters.from, filters.to, myOnly, currentUser?.id]);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Audit Logs</h2>
          <p>Track sensitive admin actions.</p>
        </div>
      </div>
      {currentUser?.id && (
        <div className="filter-chips">
          <button className={`filter-chip${!myOnly ? ' active' : ''}`} onClick={() => setMyOnly(false)}>
            All logs
          </button>
          <button className={`filter-chip${myOnly ? ' active' : ''}`} onClick={() => setMyOnly(true)}>
            My actions
          </button>
        </div>
      )}
      <div className="card-form">
        <input className="input" placeholder="Action" value={filters.action} onChange={(e) => setFilters({ ...filters, action: e.target.value })} />
        <input className="input" placeholder="Entity type" value={filters.entityType} onChange={(e) => setFilters({ ...filters, entityType: e.target.value })} />
        <input className="input" placeholder="Actor ID" value={filters.actorId} onChange={(e) => setFilters({ ...filters, actorId: e.target.value })} />
        <input className="input" type="date" value={filters.from} onChange={(e) => setFilters({ ...filters, from: e.target.value })} />
        <input className="input" type="date" value={filters.to} onChange={(e) => setFilters({ ...filters, to: e.target.value })} />
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="table table--wide">
        <div className="table-row table-row--head">
          <div>Action</div>
          <div>Actor</div>
          <div>Entity</div>
          <div>IP</div>
          <div>When</div>
        </div>
        {loading ? (
          <div className="table-row"><div>Loading...</div></div>
        ) : rows.length === 0 ? (
          <div className="table-row"><div>No logs found.</div></div>
        ) : (
          rows.map((row) => (
            <div className="table-row" key={row.id}>
              <div>{row.action}</div>
              <div>{row.actor?.name || '-'}</div>
              <div>{row.entity_type || '-'} {row.entity_id || ''}</div>
              <div>{row.ip || '-'}</div>
              <div>{row.created_at ? new Date(row.created_at).toLocaleString() : '-'}</div>
            </div>
          ))
        )}
      </div>
      <div className="pagination">
        <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
        <span>Page {page}</span>
        <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
      </div>
    </div>
  );
}

function SettingsView() {
  const [form, setForm] = useState({
    maintenance_banner: '',
    app_name: '',
    logo_url: '',
    favicon_url: '',
    primary_color: '',
    secondary_color: '',
    email_sender_name: '',
    email_sender_address: '',
    smtp_host: '',
    smtp_port: '',
    smtp_username: '',
    smtp_password: '',
    smtp_encryption: '',
    email_test_subject: '',
    email_test_body: '',
    default_visibility: 'public',
    auto_verify_alumni: false,
    require_institution_approval: false,
    max_institution_admins: '',
    require_join_approval: true,
    institution_verification_required: false,
    moderation_keywords: '',
    report_categories: '',
    moderation_auto_hide_threshold: '',
    ads_enabled: false,
    ad_placements: '',
    default_ad_price: '',
    ai_enabled: false,
    ai_confidence_threshold: '',
    ai_feed_weight: '',
    password_min_length: '',
    session_timeout_minutes: '',
    enforce_2fa: false,
    audit_log_retention_days: '',
    feature_flags: '',
    data_retention_days: '',
    default_moderation_rules: '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);
  const [defaults, setDefaults] = useState(null);
  const [uploading, setUploading] = useState({ logo: false, favicon: false });
  const [previewEnabled, setPreviewEnabled] = useState(false);
  const [previewSnapshot, setPreviewSnapshot] = useState(null);
  const [presets, setPresets] = useState([]);
  const [selectedPreset, setSelectedPreset] = useState('');
  const [presetName, setPresetName] = useState('');
  const [presetImportError, setPresetImportError] = useState('');
  const [testEmail, setTestEmail] = useState('');
  const [testEmailStatus, setTestEmailStatus] = useState('');
  const [showSmtpPassword, setShowSmtpPassword] = useState(false);
  const [dataToolsLoading, setDataToolsLoading] = useState(false);
  const [dataToolsError, setDataToolsError] = useState('');
  const [deleteConfirm, setDeleteConfirm] = useState({ open: false });

  useEffect(() => {
    fetchSystemSettings()
      .then((data) => {
        const list = data?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        setDefaults(map);
        setForm({
          maintenance_banner: map.maintenance_banner || '',
          app_name: map.app_name || '',
          logo_url: map.logo_url || '',
          favicon_url: map.favicon_url || '',
          primary_color: map.primary_color || '',
          secondary_color: map.secondary_color || '',
          email_sender_name: map.email_sender_name || '',
          email_sender_address: map.email_sender_address || '',
          smtp_host: map.smtp_host || '',
          smtp_port: map.smtp_port || '',
          smtp_username: map.smtp_username || '',
          smtp_password: map.smtp_password || '',
          smtp_encryption: map.smtp_encryption || '',
          email_test_subject: map.email_test_template?.subject || '',
          email_test_body: map.email_test_template?.body || '',
          default_visibility: map.default_visibility || 'public',
          auto_verify_alumni: map.auto_verify_alumni === true,
          require_institution_approval: map.require_institution_approval === true,
          max_institution_admins: map.max_institution_admins || '',
          require_join_approval: map.require_join_approval === true,
          institution_verification_required: map.institution_verification_required === true,
          moderation_keywords: (map.moderation_keywords || []).join(', '),
          report_categories: (map.report_categories || []).join(', '),
          moderation_auto_hide_threshold: map.moderation_auto_hide_threshold || '',
          ads_enabled: map.ads_enabled === true,
          ad_placements: (map.ad_placements || []).join(', '),
          default_ad_price: map.default_ad_price || '',
          ai_enabled: map.ai_enabled === true,
          ai_confidence_threshold: map.ai_confidence_threshold || '',
          ai_feed_weight: map.ai_feed_weight || '',
          password_min_length: map.password_min_length || '',
          session_timeout_minutes: map.session_timeout_minutes || '',
          enforce_2fa: map.enforce_2fa === true,
          audit_log_retention_days: map.audit_log_retention_days || '',
          feature_flags: (map.feature_flags || []).join(', '),
          data_retention_days: map.data_retention_days || '',
          default_moderation_rules: (map.default_moderation_rules || []).join('\n'),
        });
        if (Array.isArray(map.theme_presets)) {
          setPresets(map.theme_presets);
        }
      })
      .catch((err) => setError(err.message || 'Failed to load settings'));
  }, []);

  async function handleSave() {
    setLoading(true);
    setSaved(false);
    setError('');
    try {
      await updateSystemSettings({
        maintenance_banner: form.maintenance_banner || null,
        app_name: form.app_name || null,
        logo_url: form.logo_url || null,
        favicon_url: form.favicon_url || null,
        primary_color: form.primary_color || null,
        secondary_color: form.secondary_color || null,
        email_sender_name: form.email_sender_name || null,
        email_sender_address: form.email_sender_address || null,
        smtp_host: form.smtp_host || null,
        smtp_port: form.smtp_port ? Number(form.smtp_port) : null,
        smtp_username: form.smtp_username || null,
        smtp_password: form.smtp_password || null,
        smtp_encryption: form.smtp_encryption || null,
        email_test_template: {
          subject: form.email_test_subject || null,
          body: form.email_test_body || null,
        },
        default_visibility: form.default_visibility || null,
        auto_verify_alumni: form.auto_verify_alumni,
        require_institution_approval: form.require_institution_approval,
        max_institution_admins: form.max_institution_admins ? Number(form.max_institution_admins) : null,
        require_join_approval: form.require_join_approval,
        institution_verification_required: form.institution_verification_required,
        moderation_keywords: form.moderation_keywords
          ? form.moderation_keywords.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
        report_categories: form.report_categories
          ? form.report_categories.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
        moderation_auto_hide_threshold: form.moderation_auto_hide_threshold
          ? Number(form.moderation_auto_hide_threshold)
          : null,
        ads_enabled: form.ads_enabled,
        ad_placements: form.ad_placements
          ? form.ad_placements.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
        default_ad_price: form.default_ad_price ? Number(form.default_ad_price) : null,
        ai_enabled: form.ai_enabled,
        ai_confidence_threshold: form.ai_confidence_threshold ? Number(form.ai_confidence_threshold) : null,
        ai_feed_weight: form.ai_feed_weight ? Number(form.ai_feed_weight) : null,
        password_min_length: form.password_min_length ? Number(form.password_min_length) : null,
        session_timeout_minutes: form.session_timeout_minutes ? Number(form.session_timeout_minutes) : null,
        enforce_2fa: form.enforce_2fa,
        audit_log_retention_days: form.audit_log_retention_days ? Number(form.audit_log_retention_days) : null,
        theme_presets: presets,
        feature_flags: form.feature_flags
          ? form.feature_flags.split(',').map((s) => s.trim()).filter(Boolean)
          : [],
        data_retention_days: form.data_retention_days ? Number(form.data_retention_days) : null,
        default_moderation_rules: form.default_moderation_rules
          ? form.default_moderation_rules.split('\n').map((s) => s.trim()).filter(Boolean)
          : [],
      });
      setSaved(true);
    } catch (err) {
      setError(err.message || 'Failed to update settings');
    } finally {
      setLoading(false);
    }
  }

  function updateForm(patch) {
    setForm((prev) => ({ ...prev, ...patch }));
  }

  function renderTemplate(text) {
    if (!text) return '';
    const vars = {
      '{admin_name}': 'Admin',
      '{email}': testEmail || 'user@example.com',
      '{date}': new Date().toLocaleString(),
      '{platform_name}': form.app_name || 'Alumni Global Network',
    };
    return Object.keys(vars).reduce((acc, key) => acc.split(key).join(vars[key]), text);
  }

  async function handleExportMyData() {
    setDataToolsLoading(true);
    setDataToolsError('');
    try {
      const data = await exportMyData();
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'my-data-export.json');
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      setDataToolsError(err.message || 'Failed to export data');
    } finally {
      setDataToolsLoading(false);
    }
  }

  function handleDeleteMyAccount() {
    setDeleteConfirm({
      open: true,
      title: 'Delete account',
      message: 'This will anonymize your account data and sign you out. This cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: async () => {
        setDeleteConfirm({ open: false });
        setDataToolsLoading(true);
        setDataToolsError('');
        try {
          await deleteMyAccount();
          setToken('');
          setUser(null);
          window.location.reload();
        } catch (err) {
          setDataToolsError(err.message || 'Failed to delete account');
        } finally {
          setDataToolsLoading(false);
        }
      },
    });
  }

  function resetSection(keys) {
    if (!defaults) return;
    const next = {};
    keys.forEach((key) => {
      const val = defaults[key];
      if (Array.isArray(val)) {
        next[key] = key === 'default_moderation_rules' ? val.join('\n') : val.join(', ');
      } else if (typeof val === 'boolean') {
        next[key] = val === true;
      } else if (val === null || val === undefined) {
        next[key] = '';
      } else {
        next[key] = val;
      }
    });
    updateForm(next);
  }

  useEffect(() => {
    if (!form.primary_color && !form.secondary_color) return;
    const root = document.documentElement;
    if (form.primary_color) root.style.setProperty('--admin-primary', form.primary_color);
    if (form.secondary_color) root.style.setProperty('--admin-secondary', form.secondary_color);
    if (form.primary_color) localStorage.setItem('admin_theme_primary', form.primary_color);
    if (form.secondary_color) localStorage.setItem('admin_theme_secondary', form.secondary_color);
  }, [form.primary_color, form.secondary_color]);

  useEffect(() => {
    const savedPrimary = localStorage.getItem('admin_theme_primary');
    const savedSecondary = localStorage.getItem('admin_theme_secondary');
    const root = document.documentElement;
    if (savedPrimary) root.style.setProperty('--admin-primary', savedPrimary);
    if (savedSecondary) root.style.setProperty('--admin-secondary', savedSecondary);
  }, []);

  useEffect(() => {
    if (presets.length) return;
    const raw = localStorage.getItem('admin_theme_presets');
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) setPresets(parsed);
    } catch (_) {
      // ignore
    }
  }, [presets.length]);

  useEffect(() => {
    if (!previewEnabled) {
      if (previewSnapshot) {
        updateForm(previewSnapshot);
        setPreviewSnapshot(null);
        const root = document.documentElement;
        if (previewSnapshot.primary_color) root.style.setProperty('--admin-primary', previewSnapshot.primary_color);
        if (previewSnapshot.secondary_color) root.style.setProperty('--admin-secondary', previewSnapshot.secondary_color);
      }
      return;
    }
    if (!previewSnapshot) {
      setPreviewSnapshot({
        app_name: form.app_name,
        logo_url: form.logo_url,
        favicon_url: form.favicon_url,
        primary_color: form.primary_color,
        secondary_color: form.secondary_color,
      });
    }
  }, [previewEnabled]);

  useEffect(() => {
    if (!previewEnabled) return;
    const root = document.documentElement;
    if (form.primary_color) root.style.setProperty('--admin-primary', form.primary_color);
    if (form.secondary_color) root.style.setProperty('--admin-secondary', form.secondary_color);
  }, [previewEnabled, form.primary_color, form.secondary_color]);


  const MAX_UPLOAD_SIZE = 10 * 1024 * 1024;
  const FAVICON_SIZE = 32;
  const LOGO_WIDTH = 300;
  const LOGO_HEIGHT = 100;

  function drawCover(ctx, img, width, height) {
    const ratio = img.width / img.height;
    const targetRatio = width / height;
    let sx = 0;
    let sy = 0;
    let sw = img.width;
    let sh = img.height;
    if (ratio > targetRatio) {
      sw = img.height * targetRatio;
      sx = (img.width - sw) / 2;
    } else {
      sh = img.width / targetRatio;
      sy = (img.height - sh) / 2;
    }
    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, width, height);
  }

  async function resizeImage(file, width, height, name = 'image.png') {
    const img = new Image();
    const src = URL.createObjectURL(file);
    img.src = src;
    await new Promise((resolve) => {
      img.onload = resolve;
      img.onerror = resolve;
    });
    URL.revokeObjectURL(src);
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    if (!ctx) return file;
    drawCover(ctx, img, width, height);
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
    if (!blob) return file;
    return new File([blob], name, { type: 'image/png' });
  }

  async function handleUpload(type, file) {
    if (!file) return;
    if (file.size > MAX_UPLOAD_SIZE) {
      setError('File is too large. Max size is 10MB.');
      return;
    }
    if ((type === 'favicon' || type === 'logo') && file.type.startsWith('image/')) {
      if (type === 'logo') {
        file = await resizeImage(file, LOGO_WIDTH, LOGO_HEIGHT, 'logo.png');
      }
      if (type === 'favicon') {
        file = await resizeImage(file, FAVICON_SIZE, FAVICON_SIZE, 'favicon.png');
      }
    }
    setUploading((prev) => ({ ...prev, [type]: true }));
    try {
      const data = await uploadAdminMedia(file);
      if (data?.url) {
        updateForm(type === 'logo' ? { logo_url: data.url } : { favicon_url: data.url });
      }
    } catch (err) {
      setError(err.message || 'Upload failed');
    } finally {
      setUploading((prev) => ({ ...prev, [type]: false }));
    }
  }

  async function handleBrandUpload(file) {
    if (!file) return;
    if (file.size > MAX_UPLOAD_SIZE) {
      setError('File is too large. Max size is 10MB.');
      return;
    }
    setUploading({ logo: true, favicon: true });
    try {
      const logoFile = await resizeImage(file, LOGO_WIDTH, LOGO_HEIGHT, 'logo.png');
      const faviconFile = await resizeImage(file, FAVICON_SIZE, FAVICON_SIZE, 'favicon.png');
      const [logoRes, favRes] = await Promise.all([
        uploadAdminMedia(logoFile),
        uploadAdminMedia(faviconFile),
      ]);
      updateForm({
        logo_url: logoRes?.url || form.logo_url,
        favicon_url: favRes?.url || form.favicon_url,
      });
    } catch (err) {
      setError(err.message || 'Upload failed');
    } finally {
      setUploading({ logo: false, favicon: false });
    }
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h = 0;
    let s = 0;
    const l = (max + min) / 2;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = (g - b) / d + (g < b ? 6 : 0); break;
        case g: h = (b - r) / d + 2; break;
        case b: h = (r - g) / d + 4; break;
        default: break;
      }
      h /= 6;
    }
    return { h, s, l };
  }

  async function extractThemeFromImage(url) {
    if (!url) {
      setError('Add a logo URL first.');
      return;
    }
    try {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.src = url;
      await new Promise((resolve, reject) => {
        img.onload = resolve;
        img.onerror = reject;
      });
      const canvas = document.createElement('canvas');
      const size = 64;
      canvas.width = size;
      canvas.height = size;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.drawImage(img, 0, 0, size, size);
      const data = ctx.getImageData(0, 0, size, size).data;
      const buckets = new Map();
      for (let i = 0; i < data.length; i += 4) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const a = data[i + 3];
        if (a < 200) continue;
        if (r > 245 && g > 245 && b > 245) continue;
        if (r < 10 && g < 10 && b < 10) continue;
        const key = `${r >> 5}-${g >> 5}-${b >> 5}`;
        buckets.set(key, (buckets.get(key) || 0) + 1);
      }
      const sorted = [...buckets.entries()].sort((a, b) => b[1] - a[1]);
      if (!sorted.length) {
        setError('Could not extract colors. Try a different logo.');
        return;
      }
      const colors = sorted.map(([key]) => {
        const [r, g, b] = key.split('-').map((v) => parseInt(v, 10) * 32 + 16);
        return { r, g, b };
      });
      const primary = colors[0];
      let secondary = colors[1] || colors[0];
      const primaryHue = rgbToHsl(primary.r, primary.g, primary.b).h;
      for (const c of colors.slice(1)) {
        const hue = rgbToHsl(c.r, c.g, c.b).h;
        if (Math.abs(hue - primaryHue) > 0.08) {
          secondary = c;
          break;
        }
      }
      const toHex = (c) =>
        `#${[c.r, c.g, c.b].map((v) => v.toString(16).padStart(2, '0')).join('')}`;
      updateForm({
        primary_color: toHex(primary),
        secondary_color: toHex(secondary),
      });
    } catch (_) {
      setError('Unable to read logo colors (CORS blocked). Upload or use a local file.');
    }
  }

  function savePreset() {
    const name = presetName.trim();
    if (!name) {
      setError('Enter a preset name.');
      return;
    }
    const next = [
      ...presets.filter((p) => p.name !== name),
      { name, primary: form.primary_color, secondary: form.secondary_color },
    ];
    setPresets(next);
    localStorage.setItem('admin_theme_presets', JSON.stringify(next));
    setSelectedPreset(name);
    setPresetName('');
    updateSystemSettings({ theme_presets: next }).catch(() => {});
  }

  function applyPreset(name) {
    const preset = presets.find((p) => p.name === name);
    if (!preset) return;
    updateForm({
      primary_color: preset.primary || '',
      secondary_color: preset.secondary || '',
    });
    setSelectedPreset(name);
  }

  function deletePreset(name) {
    const next = presets.filter((p) => p.name !== name);
    setPresets(next);
    localStorage.setItem('admin_theme_presets', JSON.stringify(next));
    if (selectedPreset === name) setSelectedPreset('');
    updateSystemSettings({ theme_presets: next }).catch(() => {});
  }

  function exportPresets() {
    const payload = JSON.stringify(presets, null, 2);
    const blob = new Blob([payload], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'theme-presets.json');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  function importPresets(file) {
    if (!file) return;
    if (file.size > 2 * 1024 * 1024) {
      setPresetImportError('Preset file too large (max 2MB).');
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = JSON.parse(reader.result);
        if (!Array.isArray(parsed)) {
          setPresetImportError('Invalid preset file.');
          return;
        }
        const cleaned = parsed
          .filter((p) => p && typeof p.name === 'string')
          .map((p) => ({
            name: p.name,
            primary: p.primary || '',
            secondary: p.secondary || '',
          }));
        setPresets(cleaned);
        localStorage.setItem('admin_theme_presets', JSON.stringify(cleaned));
        updateSystemSettings({ theme_presets: cleaned }).catch(() => {});
        setPresetImportError('');
      } catch (_) {
        setPresetImportError('Invalid preset JSON.');
      }
    };
    reader.readAsText(file);
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>System Settings</h2>
          <p>Platform-wide controls for branding, security, monetization, and compliance.</p>
        </div>
      </div>
      {error && <div className="alert">{error}</div>}
      {saved && <div className="alert success">Settings updated.</div>}
      {dataToolsError && <div className="alert">{dataToolsError}</div>}
      <div className="preview-toggle">
        <label className="checkbox">
          <input
            type="checkbox"
            checked={previewEnabled}
            onChange={(e) => setPreviewEnabled(e.target.checked)}
          />
          Preview branding/theme changes without saving
        </label>
        {previewEnabled && (
          <div className="preview-banner">
            <span>Preview mode is active. Changes are not saved.</span>
            <button className="ghost" onClick={() => setPreviewEnabled(false)}>
              Revert preview
            </button>
          </div>
        )}
      </div>
      <div className="settings-stack">
        <div className="card" id="settings-monetization">
          <div className="card-header">
            <div>
              <h3>Branding</h3>
              <p>Set the name and visual identity for the platform.</p>
            </div>
            <button className="ghost" onClick={() => resetSection(['app_name', 'logo_url', 'favicon_url', 'primary_color', 'secondary_color'])}>
              Reset section
            </button>
          </div>
          <div className="card-form">
            <div className="brand-preview">
              <div className="brand-badge">
                {form.logo_url ? (
                  <img src={resolveMediaUrl(form.logo_url)} alt="Logo" />
                ) : (
                  <span>{form.app_name || 'Alumni Global Network'}</span>
                )}
              </div>
              <div className="brand-meta">
                <div className="brand-title">{form.app_name || 'Alumni Global Network'}</div>
                <div className="brand-subtitle">Admin Console Preview</div>
              </div>
            </div>
            <input className="input" placeholder="App name" value={form.app_name} onChange={(e) => updateForm({ app_name: e.target.value })} />
            <input className="input" placeholder="Logo URL" value={form.logo_url} onChange={(e) => updateForm({ logo_url: e.target.value })} />
            <div className="file-row">
              <label className="file-upload">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file && file.size > MAX_UPLOAD_SIZE) {
                      setError('File is too large. Max size is 10MB.');
                      return;
                    }
                    handleBrandUpload(file);
                  }}
                />
                {uploading.logo || uploading.favicon ? 'Uploading brand assets...' : 'Upload logo + favicon'}
              </label>
              <span className="hint">Generates 3:1 logo + 32x32 favicon.</span>
            </div>
            <div className="file-row">
              <label className="file-upload">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => handleUpload('logo', e.target.files?.[0])}
                />
                {uploading.logo ? 'Uploading logo...' : 'Upload logo'}
              </label>
              <span className="hint">Auto-cropped to 3:1 (PNG).</span>
            </div>
            <input className="input" placeholder="Favicon URL" value={form.favicon_url} onChange={(e) => updateForm({ favicon_url: e.target.value })} />
            <div className="file-row">
              <label className="file-upload">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => handleUpload('favicon', e.target.files?.[0])}
                />
                {uploading.favicon ? 'Uploading favicon...' : 'Upload favicon'}
              </label>
              <span className="hint">Auto-resized to 32x32 PNG.</span>
            </div>
            <div className="color-grid">
              <label className="color-field">
                <span>Primary color</span>
                <div>
                  <input className="input" placeholder="#2563EB" value={form.primary_color} onChange={(e) => updateForm({ primary_color: e.target.value })} />
                  <input type="color" value={form.primary_color || '#2563EB'} onChange={(e) => updateForm({ primary_color: e.target.value })} />
                </div>
              </label>
              <label className="color-field">
                <span>Secondary color</span>
                <div>
                  <input className="input" placeholder="#0F172A" value={form.secondary_color} onChange={(e) => updateForm({ secondary_color: e.target.value })} />
                  <input type="color" value={form.secondary_color || '#0F172A'} onChange={(e) => updateForm({ secondary_color: e.target.value })} />
                </div>
              </label>
            </div>
            <div className="file-row">
              <button className="ghost" onClick={() => extractThemeFromImage(form.logo_url)}>
                Auto-match colors from logo
              </button>
              <span className="hint">Uses your logo URL to set theme colors.</span>
            </div>
            <div className="preset-row">
              <select
                className="select"
                value={selectedPreset}
                onChange={(e) => applyPreset(e.target.value)}
              >
                <option value="">Theme presets</option>
                {presets.map((p) => (
                  <option key={p.name} value={p.name}>{p.name}</option>
                ))}
              </select>
              <input
                className="input"
                placeholder="New preset name"
                value={presetName}
                onChange={(e) => setPresetName(e.target.value)}
              />
              <button className="ghost" onClick={savePreset}>Save preset</button>
              <button className="ghost danger" onClick={() => deletePreset(selectedPreset)} disabled={!selectedPreset}>
                Delete preset
              </button>
            </div>
            <div className="file-row">
              <button className="ghost" onClick={exportPresets}>Export presets</button>
              <label className="file-upload">
                <input type="file" accept="application/json" onChange={(e) => importPresets(e.target.files?.[0])} />
                Import presets
              </label>
              {presetImportError && <span className="hint danger">{presetImportError}</span>}
            </div>
            {(form.logo_url || form.favicon_url) && (
              <div className="branding-preview">
                {form.logo_url && (
                  <div className="preview-tile">
                    <span>Logo preview</span>
                    <img src={resolveMediaUrl(form.logo_url)} alt="Logo preview" />
                  </div>
                )}
                {form.favicon_url && (
                  <div className="preview-tile">
                    <span>Favicon preview</span>
                    <img src={resolveMediaUrl(form.favicon_url)} alt="Favicon preview" />
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>Notifications & Email</h3>
              <p>Configure notification sender identity and SMTP details.</p>
            </div>
            <button
              className="ghost"
              onClick={() =>
                resetSection([
                  'email_sender_name',
                  'email_sender_address',
                  'smtp_host',
                  'smtp_port',
                  'smtp_username',
                  'smtp_password',
                ])
              }
            >
              Reset section
            </button>
          </div>
          <div className="card-form">
            <input className="input" placeholder="Sender name" value={form.email_sender_name} onChange={(e) => setForm({ ...form, email_sender_name: e.target.value })} />
            <input className="input" placeholder="Sender email" value={form.email_sender_address} onChange={(e) => setForm({ ...form, email_sender_address: e.target.value })} />
            <input className="input" placeholder="SMTP host" value={form.smtp_host} onChange={(e) => setForm({ ...form, smtp_host: e.target.value })} />
            <input className="input" type="number" placeholder="SMTP port" value={form.smtp_port} onChange={(e) => setForm({ ...form, smtp_port: e.target.value })} />
            <input className="input" placeholder="SMTP username" value={form.smtp_username} onChange={(e) => setForm({ ...form, smtp_username: e.target.value })} />
            <div className="input-with-icon">
              <input
                className="input"
                placeholder="SMTP password"
                type={showSmtpPassword ? 'text' : 'password'}
                value={form.smtp_password}
                onChange={(e) => setForm({ ...form, smtp_password: e.target.value })}
              />
              <button
                type="button"
                className="icon-button"
                onClick={() => setShowSmtpPassword((prev) => !prev)}
                aria-label={showSmtpPassword ? 'Hide password' : 'Show password'}
              >
                {showSmtpPassword ? 'Hide' : 'Show'}
              </button>
            </div>
            <div className="radio-group">
              <label className="radio">
                <input
                  type="radio"
                  name="smtp_encryption"
                  value="tls"
                  checked={form.smtp_encryption === 'tls'}
                  onChange={(e) => setForm({ ...form, smtp_encryption: e.target.value })}
                />
                TLS
              </label>
              <label className="radio">
                <input
                  type="radio"
                  name="smtp_encryption"
                  value="ssl"
                  checked={form.smtp_encryption === 'ssl'}
                  onChange={(e) => setForm({ ...form, smtp_encryption: e.target.value })}
                />
                SSL
              </label>
            </div>
            <input className="input" placeholder="Test email subject" value={form.email_test_subject} onChange={(e) => setForm({ ...form, email_test_subject: e.target.value })} />
            <textarea className="input" rows="3" placeholder="Test email body" value={form.email_test_body} onChange={(e) => setForm({ ...form, email_test_body: e.target.value })} />
            <div className="hint">Variables: {'{admin_name}'}, {'{email}'}, {'{date}'}, {'{platform_name}'}</div>
            <div className="email-preview">
              <div className="email-preview-title">Preview</div>
              <div className="email-preview-subject">{renderTemplate(form.email_test_subject)}</div>
              <div className="email-preview-body">{renderTemplate(form.email_test_body)}</div>
            </div>
            <div className="file-row">
              <input className="input" placeholder="Test email address" value={testEmail} onChange={(e) => setTestEmail(e.target.value)} />
              <button
                className="ghost"
                onClick={async () => {
                  if (!testEmail) return;
                  setTestEmailStatus('Sending...');
                  try {
                    await sendTestEmail(testEmail);
                    setTestEmailStatus('Sent');
                  } catch (err) {
                    setTestEmailStatus(err.message || 'Failed');
                  }
                }}
              >
                Send test
              </button>
              {testEmailStatus && <span className="hint">{testEmailStatus}</span>}
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>User Policies</h3>
              <p>Set defaults for visibility and membership governance.</p>
            </div>
            <button
              className="ghost"
              onClick={() =>
                resetSection([
                  'default_visibility',
                  'auto_verify_alumni',
                  'require_institution_approval',
                  'max_institution_admins',
                  'require_join_approval',
                  'institution_verification_required',
                ])
              }
            >
              Reset section
            </button>
          </div>
          <div className="card-form">
            <select className="select" value={form.default_visibility} onChange={(e) => setForm({ ...form, default_visibility: e.target.value })}>
              <option value="public">Public</option>
              <option value="institution_only">Institution only</option>
            </select>
            <label className="checkbox">
              <input type="checkbox" checked={form.auto_verify_alumni} onChange={(e) => setForm({ ...form, auto_verify_alumni: e.target.checked })} />
              Auto-verify alumni when a valid school ID is used
            </label>
            <label className="checkbox">
              <input type="checkbox" checked={form.require_institution_approval} onChange={(e) => setForm({ ...form, require_institution_approval: e.target.checked })} />
              Require institution approval for new school admins
            </label>
            <input className="input" type="number" placeholder="Max institution admins" value={form.max_institution_admins} onChange={(e) => setForm({ ...form, max_institution_admins: e.target.value })} />
            <label className="checkbox">
              <input type="checkbox" checked={form.require_join_approval} onChange={(e) => setForm({ ...form, require_join_approval: e.target.checked })} />
              Require approval for alumni to join an institution
            </label>
            <label className="checkbox">
              <input type="checkbox" checked={form.institution_verification_required} onChange={(e) => setForm({ ...form, institution_verification_required: e.target.checked })} />
              Institution profile verification required before going live
            </label>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>Moderation</h3>
              <p>Automated rules and report categories.</p>
            </div>
            <button
              className="ghost"
              onClick={() =>
                resetSection([
                  'maintenance_banner',
                  'default_moderation_rules',
                  'moderation_keywords',
                  'report_categories',
                  'moderation_auto_hide_threshold',
                ])
              }
            >
              Reset section
            </button>
          </div>
          <div className="card-form">
            <textarea className="input" rows="2" placeholder="Maintenance banner" value={form.maintenance_banner} onChange={(e) => setForm({ ...form, maintenance_banner: e.target.value })} />
            <textarea className="input" rows="3" placeholder="Default moderation rules (one per line)" value={form.default_moderation_rules} onChange={(e) => setForm({ ...form, default_moderation_rules: e.target.value })} />
            <input className="input" placeholder="Moderation keywords (comma)" value={form.moderation_keywords} onChange={(e) => setForm({ ...form, moderation_keywords: e.target.value })} />
            <input className="input" placeholder="Report categories (comma)" value={form.report_categories} onChange={(e) => setForm({ ...form, report_categories: e.target.value })} />
            <input className="input" type="number" placeholder="Auto-hide threshold (# of reports)" value={form.moderation_auto_hide_threshold} onChange={(e) => setForm({ ...form, moderation_auto_hide_threshold: e.target.value })} />
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>Ads & Promotions</h3>
              <p>Enable ads and define placements/pricing.</p>
            </div>
            <button className="ghost" onClick={() => resetSection(['ads_enabled', 'ad_placements', 'default_ad_price'])}>
              Reset section
            </button>
          </div>
          <div className="card-form">
            <label className="checkbox">
              <input type="checkbox" checked={form.ads_enabled} onChange={(e) => setForm({ ...form, ads_enabled: e.target.checked })} />
              Ads enabled
            </label>
            <input className="input" placeholder="Ad placements (comma)" value={form.ad_placements} onChange={(e) => setForm({ ...form, ad_placements: e.target.value })} />
            <input className="input" type="number" placeholder="Default ad price" value={form.default_ad_price} onChange={(e) => setForm({ ...form, default_ad_price: e.target.value })} />
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>AI & Recommendations</h3>
              <p>Control AI personalization and ranking weights.</p>
            </div>
            <button
              className="ghost"
              onClick={() => resetSection(['ai_enabled', 'ai_confidence_threshold', 'ai_feed_weight'])}
            >
              Reset section
            </button>
          </div>
          <div className="card-form">
            <label className="checkbox">
              <input type="checkbox" checked={form.ai_enabled} onChange={(e) => setForm({ ...form, ai_enabled: e.target.checked })} />
              AI personalization enabled
            </label>
            <input className="input" type="number" step="0.01" min="0" max="1" placeholder="AI confidence threshold (0-1)" value={form.ai_confidence_threshold} onChange={(e) => setForm({ ...form, ai_confidence_threshold: e.target.value })} />
            <input className="input" type="number" step="0.01" min="0" max="1" placeholder="AI feed weight (0-1)" value={form.ai_feed_weight} onChange={(e) => setForm({ ...form, ai_feed_weight: e.target.value })} />
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>Security</h3>
              <p>Control password rules and admin session settings.</p>
            </div>
            <button
              className="ghost"
              onClick={() =>
                resetSection(['password_min_length', 'session_timeout_minutes', 'enforce_2fa'])
              }
            >
              Reset section
            </button>
          </div>
          <div className="card-form">
            <input className="input" type="number" placeholder="Password min length" value={form.password_min_length} onChange={(e) => setForm({ ...form, password_min_length: e.target.value })} />
            <input className="input" type="number" placeholder="Session timeout (minutes)" value={form.session_timeout_minutes} onChange={(e) => setForm({ ...form, session_timeout_minutes: e.target.value })} />
            <label className="checkbox">
              <input type="checkbox" checked={form.enforce_2fa} onChange={(e) => setForm({ ...form, enforce_2fa: e.target.checked })} />
              Enforce 2FA for admins
            </label>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>Compliance</h3>
              <p>Retention rules and global feature flags.</p>
            </div>
            <button
              className="ghost"
              onClick={() => resetSection(['data_retention_days', 'audit_log_retention_days', 'feature_flags'])}
            >
              Reset section
            </button>
          </div>
          <div className="card-form">
            <input className="input" type="number" placeholder="Data retention (days)" value={form.data_retention_days} onChange={(e) => setForm({ ...form, data_retention_days: e.target.value })} />
            <input className="input" type="number" placeholder="Audit log retention (days)" value={form.audit_log_retention_days} onChange={(e) => setForm({ ...form, audit_log_retention_days: e.target.value })} />
            <input className="input" placeholder="Feature flags (comma)" value={form.feature_flags} onChange={(e) => setForm({ ...form, feature_flags: e.target.value })} />
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <div>
              <h3>Privacy & data</h3>
              <p>Export your data or delete your admin account.</p>
            </div>
          </div>
          <div className="card-form">
            <button className="ghost" onClick={handleExportMyData} disabled={dataToolsLoading}>
              Export my data
            </button>
            <button className="ghost danger" onClick={handleDeleteMyAccount} disabled={dataToolsLoading}>
              Delete my account
            </button>
          </div>
        </div>

        <button className="primary" onClick={handleSave} disabled={loading}>
          {loading ? 'Saving...' : 'Save settings'}
        </button>
        <button className="ghost" onClick={() => resetSection(Object.keys(form))} disabled={!defaults}>
          Reset all settings
        </button>
      </div>
      <ConfirmModal
        open={deleteConfirm.open}
        title={deleteConfirm.title}
        message={deleteConfirm.message}
        confirmLabel={deleteConfirm.confirmLabel}
        onCancel={() => setDeleteConfirm({ open: false })}
        onConfirm={deleteConfirm.onConfirm}
      />
    </div>
  );
}

function RolesPermissionsView() {
  const [permissions, setPermissions] = useState(DEFAULT_ADMIN_PERMISSIONS);
  const [roleCatalog, setRoleCatalog] = useState(getRoleCatalog());
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [newRole, setNewRole] = useState({ key: '', label: '', portal: 'admin' });
  const [selectedRoleKey, setSelectedRoleKey] = useState('');
  const [roleModal, setRoleModal] = useState({ open: false, roleKey: '', draft: null });

  const roleOptions = useMemo(
    () =>
      Object.entries(roleCatalog).map(([key, value]) => ({
        key,
        label: value?.label || key,
      })),
    [roleCatalog]
  );

  useEffect(() => {
    setLoading(true);
    setError('');
    fetchSystemSettings()
      .then((res) => {
        const list = res?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        const stored = map.admin_permissions;
        const merged = { ...DEFAULT_ADMIN_PERMISSIONS };
        if (stored && typeof stored === 'object') {
          ADMIN_PERMISSION_DEFS.forEach((item) => {
            if (Object.prototype.hasOwnProperty.call(stored, item.key)) {
              merged[item.key] = !!stored[item.key];
            }
          });
        }
        setPermissions(merged);
        setRoleCatalog(getRoleCatalog(map.role_catalog));
      })
      .catch((err) => setError(err.message || 'Failed to load roles & permissions'))
      .finally(() => setLoading(false));
  }, []);

  async function handleSave() {
    setSaving(true);
    setSaved(false);
    setError('');
    try {
      const normalizedCatalog = Object.fromEntries(
        Object.entries(roleCatalog).map(([role, config]) => [
          role,
          {
            label: config.label,
            portal: config.portal,
            permissions: ADMIN_PERMISSION_DEFS.reduce((acc, item) => {
              acc[item.key] = !!config.permissions?.[item.key];
              return acc;
            }, {}),
          },
        ])
      );
      await updateSystemSettings({
        admin_permissions: permissions,
        role_catalog: normalizedCatalog,
      });
      setSaved(true);
    } catch (err) {
      setError(err.message || 'Failed to save roles & permissions');
    } finally {
      setSaving(false);
    }
  }

  async function persistRoleCatalog(nextCatalog, nextPermissions = permissions) {
    setSaving(true);
    setSaved(false);
    setError('');
    try {
      const normalizedCatalog = Object.fromEntries(
        Object.entries(nextCatalog).map(([role, config]) => [
          role,
          {
            label: config.label,
            portal: config.portal,
            permissions: ADMIN_PERMISSION_DEFS.reduce((acc, item) => {
              acc[item.key] = !!config.permissions?.[item.key];
              return acc;
            }, {}),
          },
        ])
      );
      await updateSystemSettings({
        admin_permissions: nextPermissions,
        role_catalog: normalizedCatalog,
      });
      setPermissions(nextPermissions);
      setRoleCatalog(nextCatalog);
      setSaved(true);
      return true;
    } catch (err) {
      setError(err.message || 'Failed to save roles & permissions');
      return false;
    } finally {
      setSaving(false);
    }
  }

  function updateRolePermission(roleKey, permissionKey, enabled) {
    setRoleCatalog((prev) => ({
      ...prev,
      [roleKey]: {
        ...prev[roleKey],
        permissions: {
          ...(prev[roleKey]?.permissions || {}),
          [permissionKey]: enabled,
        },
      },
    }));
    if (roleKey === 'institution_admin') {
      setPermissions((prev) => ({
        ...prev,
        [permissionKey]: enabled,
      }));
    }
  }

  function addRole() {
    const key = newRole.key.trim().toLowerCase().replace(/[^a-z0-9_]+/g, '_');
    const label = newRole.label.trim();
    if (!key || !label) {
      setError('Role key and label are required.');
      return;
    }
    if (key === 'alumni') {
      setError('Alumni is already a system role.');
      return;
    }
    if (roleCatalog[key]) {
      setError('That role already exists.');
      return;
    }
    setError('');
    setRoleCatalog((prev) => ({
      ...prev,
      [key]: {
        label,
        portal: newRole.portal,
        permissions: ADMIN_PERMISSION_DEFS.reduce((acc, item) => {
          acc[item.key] = false;
          return acc;
        }, {}),
      },
    }));
    setNewRole({ key: '', label: '', portal: 'admin' });
  }

  function removeRole(roleKey) {
    if (['institution_admin', 'accountant', 'support_agent'].includes(roleKey)) {
      setError('Built-in roles cannot be removed.');
      return;
    }
    setRoleCatalog((prev) => {
      const next = { ...prev };
      delete next[roleKey];
      return next;
    });
  }

  function openRoleEditor(roleKey) {
    const role = roleCatalog[roleKey];
    if (!role) return;
    setRoleModal({
      open: true,
      roleKey,
      draft: {
        label: role.label,
        portal: role.portal,
        permissions: { ...(role.permissions || {}) },
      },
    });
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Roles & permissions</h2>
          <p>Control what dashboard roles can access. Super admins always have full access.</p>
        </div>
      </div>

      {error && <div className="alert">{error}</div>}
      {saved && <div className="alert success">Permissions updated.</div>}

      <div className="card">
        <div className="card-header">
          <div>
            <h3>User Roles & Access Control</h3>
            <p>Choose a role, open its permission sheet, and save without scrolling through every role block.</p>
          </div>
        </div>
        <div className="card-form" style={{ gridTemplateColumns: '1.1fr 1.3fr 1fr auto' }}>
          <input
            className="input"
            placeholder="role_key"
            value={newRole.key}
            onChange={(e) => setNewRole((prev) => ({ ...prev, key: e.target.value }))}
          />
          <input
            className="input"
            placeholder="Role label"
            value={newRole.label}
            onChange={(e) => setNewRole((prev) => ({ ...prev, label: e.target.value }))}
          />
          <select
            className="select"
            value={newRole.portal}
            onChange={(e) => setNewRole((prev) => ({ ...prev, portal: e.target.value }))}
          >
            <option value="admin">Admin portal</option>
            <option value="accounting">Accounting portal</option>
            <option value="support">Support portal</option>
          </select>
          <button className="ghost" onClick={addRole}>Add role</button>
        </div>
        <div className="card-form" style={{ gridTemplateColumns: '1fr auto', marginTop: 12 }}>
          <select
            className="select"
            value={selectedRoleKey}
            onChange={(e) => setSelectedRoleKey(e.target.value)}
          >
            <option value="">Select a role...</option>
            {roleOptions.map((option) => (
              <option key={option.key} value={option.key}>{option.label}</option>
            ))}
          </select>
          <button
            className="primary"
            onClick={() => openRoleEditor(selectedRoleKey)}
            disabled={!selectedRoleKey || loading || saving}
          >
            Assign permissions
          </button>
        </div>
        <div className="hint" style={{ marginTop: 8 }}>
          1) Choose a role {'->'} 2) Tick permissions in the popup {'->'} 3) Save.
        </div>
      </div>

      <div className="panel-actions" style={{ marginTop: 16 }}>
        <button
          className="ghost"
          onClick={() => {
            setPermissions({ ...DEFAULT_ADMIN_PERMISSIONS });
            setRoleCatalog(getRoleCatalog());
          }}
          disabled={loading || saving}
        >
          Reset defaults
        </button>
      </div>

      {roleModal.open && roleModal.draft && (
        <div className="modal-backdrop" onClick={() => setRoleModal({ open: false, roleKey: '', draft: null })}>
          <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
            <div className="modal-title">Assign Permissions</div>
            <div className="modal-message">
              Role: {roleModal.draft.label}
            </div>
            <div className="card-form" style={{ gridTemplateColumns: '1fr 1fr', marginBottom: 16 }}>
              <label>
                <div className="hint" style={{ marginBottom: 6 }}>Role label</div>
                <input
                  className="input"
                  value={roleModal.draft.label}
                  onChange={(e) =>
                    setRoleModal((prev) => ({
                      ...prev,
                      draft: { ...prev.draft, label: e.target.value },
                    }))
                  }
                />
              </label>
              <label>
                <div className="hint" style={{ marginBottom: 6 }}>Portal</div>
                <select
                  className="select"
                  value={roleModal.draft.portal}
                  onChange={(e) =>
                    setRoleModal((prev) => ({
                      ...prev,
                      draft: { ...prev.draft, portal: e.target.value },
                    }))
                  }
                >
                  <option value="admin">Admin portal</option>
                  <option value="accounting">Accounting portal</option>
                  <option value="support">Support portal</option>
                </select>
              </label>
            </div>
            <div className="card-form" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
              {ADMIN_PERMISSION_DEFS.map((item) => (
                <label
                  key={`${roleModal.roleKey}-${item.key}`}
                  className="card"
                  style={{ padding: 16, display: 'flex', gap: 12, alignItems: 'flex-start', margin: 0 }}
                >
                  <input
                    type="checkbox"
                    checked={!!roleModal.draft.permissions?.[item.key]}
                    onChange={(e) =>
                      setRoleModal((prev) => ({
                        ...prev,
                        draft: {
                          ...prev.draft,
                          permissions: {
                            ...(prev.draft.permissions || {}),
                            [item.key]: e.target.checked,
                          },
                        },
                      }))
                    }
                  />
                  <div>
                    <div style={{ fontWeight: 600 }}>{item.label}</div>
                    <div className="hint">{item.help}</div>
                  </div>
                </label>
              ))}
            </div>
            <div className="modal-actions">
              {!['institution_admin', 'accountant', 'support_agent'].includes(roleModal.roleKey) && (
                <button
                  className="ghost danger"
                  onClick={() => {
                    removeRole(roleModal.roleKey);
                    setRoleModal({ open: false, roleKey: '', draft: null });
                    if (selectedRoleKey === roleModal.roleKey) setSelectedRoleKey('');
                  }}
                >
                  Remove role
                </button>
              )}
              <button className="ghost" onClick={() => setRoleModal({ open: false, roleKey: '', draft: null })}>
                Cancel
              </button>
              <button
                className="primary"
                disabled={saving}
                onClick={async () => {
                  const nextCatalog = {
                    ...roleCatalog,
                    [roleModal.roleKey]: {
                      label: roleModal.draft.label.trim() || roleModal.roleKey,
                      portal: roleModal.draft.portal,
                      permissions: { ...(roleModal.draft.permissions || {}) },
                    },
                  };
                  const nextPermissions = roleModal.roleKey === 'institution_admin'
                    ? { ...(roleModal.draft.permissions || {}) }
                    : permissions;
                  const ok = await persistRoleCatalog(nextCatalog, nextPermissions);
                  if (ok) {
                    setSelectedRoleKey(roleModal.roleKey);
                    setRoleModal({ open: false, roleKey: '', draft: null });
                  }
                }}
              >
                {saving ? 'Saving...' : 'Save changes'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function MentorshipView({ institutionId, institutions = [], isSuper = false, scopeLabel }) {
  const navigate = useNavigate();
  const [rows, setRows] = useState([]);
  const [yearGroups, setYearGroups] = useState([]);
  const [yearGroupRequests, setYearGroupRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [yearGroupLoading, setYearGroupLoading] = useState(false);
  const [yearGroupSaving, setYearGroupSaving] = useState(false);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [institutionFilter, setInstitutionFilter] = useState('');
  const [focus, setFocus] = useState('all');
  const [yearGroupForm, setYearGroupForm] = useState({
    name: '',
    graduation_year: '',
    description: '',
  });
  const [yearGroupAssignForm, setYearGroupAssignForm] = useState({
    group_id: '',
    user_id: '',
  });

  const effectiveInstitutionId = institutionId || (institutionFilter ? Number(institutionFilter) : undefined);

  useEffect(() => {
    let ignore = false;
    async function load() {
      setLoading(true);
      setError('');
      try {
        const data = await fetchUsers({
          search,
          status: 'active',
          institutionId: effectiveInstitutionId,
          perPage: 30,
        });
        if (!ignore) {
          setRows(data?.data || []);
        }
      } catch (err) {
        if (!ignore) setError(err.message || 'Failed to load mentorship directory');
      } finally {
        if (!ignore) setLoading(false);
      }
    }
    load();
    return () => {
      ignore = true;
    };
  }, [search, effectiveInstitutionId]);

  useEffect(() => {
    let ignore = false;
    async function loadYearGroups() {
      if (!effectiveInstitutionId) {
        setYearGroups([]);
        setYearGroupRequests([]);
        return;
      }
      setYearGroupLoading(true);
      try {
        const [groupsPayload, requestsPayload] = await Promise.all([
          fetchInstitutionYearGroups(effectiveInstitutionId),
          fetchInstitutionYearGroupRequests(effectiveInstitutionId, { page: 1, perPage: 20 }),
        ]);
        if (!ignore) {
          setYearGroups(groupsPayload?.data || []);
          setYearGroupRequests(requestsPayload?.data || []);
        }
      } catch (err) {
        if (!ignore) setError(err.message || 'Failed to load year groups');
      } finally {
        if (!ignore) setYearGroupLoading(false);
      }
    }
    loadYearGroups();
    return () => {
      ignore = true;
    };
  }, [effectiveInstitutionId]);

  const alumniRows = rows.filter((row) => row.role === 'alumni');
  const adminRows = rows.filter((row) => row.role === 'institution_admin');
  const mentorReadyRows = rows.filter((row) => row.status === 'active');
  const yearGroupCount = yearGroups.length;
  const yearGroupPending = yearGroupRequests.length;
  const filteredRows = rows.filter((row) => {
    if (focus === 'alumni') return row.role === 'alumni';
    if (focus === 'school') return row.role === 'institution_admin';
    if (focus === 'active') return row.status === 'active';
    return true;
  });

  async function handleCreateYearGroup(e) {
    e.preventDefault();
    if (!effectiveInstitutionId || !yearGroupForm.name.trim()) return;
    setYearGroupSaving(true);
    setError('');
    try {
      const payload = await createInstitutionYearGroup(effectiveInstitutionId, {
        name: yearGroupForm.name.trim(),
        graduation_year: yearGroupForm.graduation_year ? Number(yearGroupForm.graduation_year) : null,
        description: yearGroupForm.description?.trim() || null,
      });
      setYearGroups((prev) => [payload?.group || payload, ...prev].filter(Boolean));
      setYearGroupForm({ name: '', graduation_year: '', description: '' });
    } catch (err) {
      setError(err.message || 'Failed to create year group');
    } finally {
      setYearGroupSaving(false);
    }
  }

  async function handleYearGroupDecision(id, action) {
    if (!effectiveInstitutionId) return;
    try {
      if (action === 'approve') {
        await approveInstitutionYearGroupRequest(effectiveInstitutionId, id);
      } else {
        await rejectInstitutionYearGroupRequest(effectiveInstitutionId, id);
      }
      setYearGroupRequests((prev) => prev.filter((row) => row.id !== id));
      const groupsPayload = await fetchInstitutionYearGroups(effectiveInstitutionId);
      setYearGroups(groupsPayload?.data || []);
    } catch (err) {
      setError(err.message || 'Failed to update year-group request');
    }
  }

  async function handleAddAlumniToYearGroup(e) {
    e.preventDefault();
    if (!effectiveInstitutionId || !yearGroupAssignForm.group_id || !yearGroupAssignForm.user_id) return;
    try {
      await addInstitutionYearGroupMember(
        effectiveInstitutionId,
        Number(yearGroupAssignForm.group_id),
        Number(yearGroupAssignForm.user_id),
      );
      setYearGroupAssignForm({ group_id: '', user_id: '' });
      const [groupsPayload, requestsPayload] = await Promise.all([
        fetchInstitutionYearGroups(effectiveInstitutionId),
        fetchInstitutionYearGroupRequests(effectiveInstitutionId, { page: 1, perPage: 20 }),
      ]);
      setYearGroups(groupsPayload?.data || []);
      setYearGroupRequests(requestsPayload?.data || []);
    } catch (err) {
      setError(err.message || 'Failed to add alumni to year group');
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Mentorship</h2>
          <p>
            Spot mentors, school guides, and active community members who can support alumni growth.
          </p>
        </div>
        <button
          className="ghost"
          onClick={() => navigate(isSuper ? '/super/directory' : '/institution/directory')}
        >
          Open directory
        </button>
      </div>
      <ScopeNote label={scopeLabel} />

      <div className="metrics-grid reports-metrics">
        <div className="metric">
          <div className="metric-title">Visible mentors</div>
          <div className="metric-value">{alumniRows.length}</div>
          <div className="metric-subtitle">Active alumni profiles in view</div>
        </div>
        <div className="metric">
          <div className="metric-title">School leads</div>
          <div className="metric-value">{adminRows.length}</div>
          <div className="metric-subtitle">Institution admins available to guide</div>
        </div>
        <div className="metric">
          <div className="metric-title">Community pool</div>
          <div className="metric-value">{rows.length}</div>
          <div className="metric-subtitle">People available for matching and outreach</div>
        </div>
        <div className="metric">
          <div className="metric-title">Ready now</div>
          <div className="metric-value">{mentorReadyRows.length}</div>
          <div className="metric-subtitle">Profiles currently active and available</div>
        </div>
        <div className="metric">
          <div className="metric-title">Year groups</div>
          <div className="metric-value">{yearGroupCount}</div>
          <div className="metric-subtitle">Graduation circles available to alumni</div>
        </div>
        <div className="metric">
          <div className="metric-title">Group approvals</div>
          <div className="metric-value">{yearGroupPending}</div>
          <div className="metric-subtitle">Requests waiting on school admins</div>
        </div>
      </div>

      <div className="card-form">
        <input
          className="input"
          placeholder="Search mentors, alumni, or school leads"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        {isSuper && institutions.length > 0 && (
          <select className="select" value={institutionFilter} onChange={(e) => setInstitutionFilter(e.target.value)}>
            <option value="">All institutions</option>
            {institutions.map((inst) => (
              <option key={inst.id} value={inst.id}>{inst.name}</option>
            ))}
          </select>
        )}
      </div>

      <div className="card" style={{ marginBottom: 16 }}>
        <h3>{isSuper ? 'How to use mentorship' : 'How your school can use mentorship'}</h3>
        <p>
          {isSuper
            ? 'Use this view to spot strong alumni mentors, active school leads, and community members who can support relationship-building across institutions.'
            : 'Use this view to surface alumni who can mentor, identify school leads who should respond quickly, and keep your institution visible as a place that supports alumni growth.'}
        </p>
      </div>

      <div className="chip-row" style={{ marginBottom: 16 }}>
        {[
          ['all', 'All'],
          ['alumni', 'Alumni mentors'],
          ['school', 'School leads'],
          ['active', 'Active now'],
        ].map(([value, label]) => (
          <button
            key={value}
            type="button"
            className={`pill ${focus === value ? 'pill--active' : ''}`}
            onClick={() => setFocus(value)}
          >
            {label}
          </button>
        ))}
      </div>

      {error && <div className="alert">{error}</div>}

      <div className="grid two" style={{ marginBottom: 16, alignItems: 'start' }}>
        <div className="card">
          <h3>Year groups</h3>
          <p>
            Create graduation circles that alumni can request to join. Super admins and school admins can
            create them, but only school admins approve membership.
          </p>
          {effectiveInstitutionId ? (
            <form className="card-form" onSubmit={handleCreateYearGroup}>
              <input
                className="input"
                placeholder="Group name"
                value={yearGroupForm.name}
                onChange={(e) => setYearGroupForm((prev) => ({ ...prev, name: e.target.value }))}
              />
              <input
                className="input"
                placeholder="Graduation year"
                value={yearGroupForm.graduation_year}
                onChange={(e) => setYearGroupForm((prev) => ({ ...prev, graduation_year: e.target.value }))}
              />
              <textarea
                className="textarea"
                placeholder="Description"
                value={yearGroupForm.description}
                onChange={(e) => setYearGroupForm((prev) => ({ ...prev, description: e.target.value }))}
              />
              <button className="primary" type="submit" disabled={yearGroupSaving}>
                {yearGroupSaving ? 'Creating...' : 'Create year group'}
              </button>
            </form>
          ) : (
            <div className="empty-state">Select an institution first to create year groups.</div>
          )}
          {!isSuper && effectiveInstitutionId && yearGroups.length > 0 && alumniRows.length > 0 && (
            <form className="card-form" style={{ marginTop: 12 }} onSubmit={handleAddAlumniToYearGroup}>
              <select
                className="select"
                value={yearGroupAssignForm.group_id}
                onChange={(e) => setYearGroupAssignForm((prev) => ({ ...prev, group_id: e.target.value }))}
              >
                <option value="">Select year group</option>
                {yearGroups.map((group) => (
                  <option key={group.id} value={group.id}>
                    {group.name}{group.graduation_year ? ` • ${group.graduation_year}` : ''}
                  </option>
                ))}
              </select>
              <select
                className="select"
                value={yearGroupAssignForm.user_id}
                onChange={(e) => setYearGroupAssignForm((prev) => ({ ...prev, user_id: e.target.value }))}
              >
                <option value="">Select alumni</option>
                {alumniRows.map((row) => (
                  <option key={row.id} value={row.id}>
                    {row.name || 'Unknown'}{row.profile?.graduation_year ? ` • ${row.profile.graduation_year}` : ''}
                  </option>
                ))}
              </select>
              <button className="ghost" type="submit">
                Add alumni
              </button>
            </form>
          )}
          <div className="table" style={{ marginTop: 12 }}>
            <div className="table-row table-row--head">
              <div>Name</div>
              <div>Year</div>
              <div>Members</div>
              <div>Pending</div>
            </div>
            {yearGroupLoading ? (
              <div className="table-row"><div>Loading...</div></div>
            ) : yearGroups.length === 0 ? (
              <div className="table-row"><div>No year groups yet.</div></div>
            ) : (
              yearGroups.map((group) => (
                <div className="table-row" key={group.id}>
                  <div className="title-cell">
                    <strong>{group.name}</strong>
                    <span>{group.description || 'Graduation circle for alumni'}</span>
                  </div>
                  <div>{group.graduation_year || '-'}</div>
                  <div>{group.counts?.approved_members || 0}</div>
                  <div>{group.counts?.pending_members || 0}</div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="card">
          <h3>Pending year-group approvals</h3>
          <p>
            School admins approve these requests so only the right alumni enter each year group.
            {isSuper ? ' Super admins can review the queue, but approval stays with the school admin.' : ''}
          </p>
          <div className="table">
            <div className="table-row table-row--head">
              <div>Member</div>
              <div>Year group</div>
              <div>Intro</div>
              <div>Action</div>
            </div>
            {yearGroupLoading ? (
              <div className="table-row"><div>Loading...</div></div>
            ) : yearGroupRequests.length === 0 ? (
              <div className="table-row"><div>No pending year-group requests.</div></div>
            ) : (
              yearGroupRequests.map((row) => (
                <div className="table-row" key={row.id}>
                  <div className="title-cell">
                    <strong>{row.user?.name || 'Unknown'}</strong>
                    <span>{row.user?.email || '-'}</span>
                  </div>
                  <div>
                    {row.year_group?.name || '-'}
                    {row.year_group?.graduation_year ? ` • ${row.year_group.graduation_year}` : ''}
                  </div>
                  <div>{row.intro || '-'}</div>
                  <div className="actions">
                    {isSuper ? (
                      <span className="status-badge">School admin approval only</span>
                    ) : (
                      <>
                        <button className="primary" onClick={() => handleYearGroupDecision(row.id, 'approve')}>Approve</button>
                        <button className="ghost" onClick={() => handleYearGroupDecision(row.id, 'reject')}>Reject</button>
                      </>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      <div className="card">
        <h3>Recommended mentorship pool</h3>
        <p>
          Use this list to identify experienced alumni, school administrators, and active members who can
          support mentorship outreach. The same pool can support student mentoring, alumni guidance, and
          school-led relationship building.
        </p>
        <div className="table table--users">
          <div className="table-row table-row--head">
            <div>Name</div>
            <div>Role</div>
            <div>Institution</div>
            <div>Status</div>
          </div>
          {loading ? (
            <div className="table-row"><div>Loading...</div></div>
          ) : filteredRows.length === 0 ? (
            <div className="table-row"><div>No mentorship candidates found.</div></div>
          ) : (
            filteredRows.map((row) => (
              <div className="table-row" key={row.id}>
                <div className="title-cell">
                  <strong>{row.name || 'Unknown'}</strong>
                  <span>{row.email || '-'}</span>
                </div>
                <div>{(row.role || '-').replaceAll('_', ' ')}</div>
                <div>{row.institution?.name || '-'}</div>
                <div><StatusPill status={row.status || 'active'} /></div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function MonetizationView() {
  const [form, setForm] = useState({
    platform_fee_enabled: true,
    platform_fee_percent: '',
    default_currency: '',
    payout_schedule: 'monthly',
    refund_window_days: '',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);
  const [platformSettings, setPlatformSettings] = useState(null);
  const [platformForm, setPlatformForm] = useState({
    stripe_public_key: '',
    stripe_secret_key: '',
    paystack_public_key: '',
    paystack_secret_key: '',
    paypal_client_id: '',
    paypal_client_secret: '',
    flutterwave_public_key: '',
    flutterwave_secret_key: '',
  });
  const [platformSaving, setPlatformSaving] = useState({});

  useEffect(() => {
    fetchSystemSettings()
      .then((data) => {
        const list = data?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        setForm({
          platform_fee_enabled: map.platform_fee_enabled !== false,
          platform_fee_percent: map.platform_fee_percent || '',
          default_currency: map.default_currency || '',
          payout_schedule: map.payout_schedule || 'monthly',
          refund_window_days: map.refund_window_days || '',
        });
      })
      .catch((err) => setError(err.message || 'Failed to load settings'));

    fetchPlatformPaymentSettings()
      .then((data) => setPlatformSettings(data?.settings || null))
      .catch(() => {});
  }, []);

  async function handleSave() {
    setLoading(true);
    setSaved(false);
    setError('');
    try {
      await updateSystemSettings({
        platform_fee_enabled: form.platform_fee_enabled,
        platform_fee_percent: form.platform_fee_percent ? Number(form.platform_fee_percent) : null,
        default_currency: form.default_currency || null,
        payout_schedule: form.payout_schedule || null,
        refund_window_days: form.refund_window_days ? Number(form.refund_window_days) : null,
      });
      setSaved(true);
    } catch (err) {
      setError(err.message || 'Failed to update settings');
    } finally {
      setLoading(false);
    }
  }

  async function handlePlatformSave(provider) {
    setError('');
    setSaved(false);
    const payload = {};
    if (provider === 'stripe') {
      if (platformForm.stripe_public_key?.trim()) payload.stripe_public_key = platformForm.stripe_public_key.trim();
      if (platformForm.stripe_secret_key?.trim()) payload.stripe_secret_key = platformForm.stripe_secret_key.trim();
    }
    if (provider === 'paystack') {
      if (platformForm.paystack_public_key?.trim()) payload.paystack_public_key = platformForm.paystack_public_key.trim();
      if (platformForm.paystack_secret_key?.trim()) payload.paystack_secret_key = platformForm.paystack_secret_key.trim();
    }
    if (provider === 'paypal') {
      if (platformForm.paypal_client_id?.trim()) payload.paypal_client_id = platformForm.paypal_client_id.trim();
      if (platformForm.paypal_client_secret?.trim()) payload.paypal_client_secret = platformForm.paypal_client_secret.trim();
    }
    if (provider === 'flutterwave') {
      if (platformForm.flutterwave_public_key?.trim()) payload.flutterwave_public_key = platformForm.flutterwave_public_key.trim();
      if (platformForm.flutterwave_secret_key?.trim()) payload.flutterwave_secret_key = platformForm.flutterwave_secret_key.trim();
    }
    if (!Object.keys(payload).length) {
      setError('Enter at least one key to update.');
      return;
    }
    setPlatformSaving((prev) => ({ ...prev, [provider]: true }));
    try {
      await updatePlatformPaymentSettings(payload);
      setPlatformForm((prev) => ({
        ...prev,
        ...(provider === 'stripe' ? { stripe_public_key: '', stripe_secret_key: '' } : {}),
        ...(provider === 'paystack' ? { paystack_public_key: '', paystack_secret_key: '' } : {}),
        ...(provider === 'paypal' ? { paypal_client_id: '', paypal_client_secret: '' } : {}),
        ...(provider === 'flutterwave' ? { flutterwave_public_key: '', flutterwave_secret_key: '' } : {}),
      }));
      const data = await fetchPlatformPaymentSettings();
      setPlatformSettings(data?.settings || null);
      setSaved(`${provider} saved`);
    } catch (err) {
      const details = err?.data?.errors
        ? Object.values(err.data.errors).flat()[0]
        : null;
      setError(details || err.message || 'Failed to update platform payment settings');
    } finally {
      setPlatformSaving((prev) => ({ ...prev, [provider]: false }));
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Monetization</h2>
          <p>Configure fees, currency, and refund rules.</p>
        </div>
        <div className="panel-actions">
          <button className="primary" onClick={handleSave} disabled={loading}>
            {loading ? 'Saving...' : 'Save changes'}
          </button>
        </div>
      </div>
      {error && <div className="alert">{error}</div>}
      {saved && <div className="alert success">Monetization settings updated.</div>}
      <div className="card support-card">
        <div className="card-form">
          <label className="checkbox">
            <input
              type="checkbox"
              checked={form.platform_fee_enabled}
              onChange={(e) => setForm({ ...form, platform_fee_enabled: e.target.checked })}
            />
            Enable platform fee
          </label>
          <input
            className="input"
            type="number"
            placeholder="Platform fee (%)"
            value={form.platform_fee_percent}
            onChange={(e) => setForm({ ...form, platform_fee_percent: e.target.value })}
          />
          <input
            className="input"
            placeholder="Default currency"
            value={form.default_currency}
            onChange={(e) => setForm({ ...form, default_currency: e.target.value })}
          />
          <select
            className="select"
            value={form.payout_schedule}
            onChange={(e) => setForm({ ...form, payout_schedule: e.target.value })}
          >
            <option value="weekly">Weekly</option>
            <option value="biweekly">Biweekly</option>
            <option value="monthly">Monthly</option>
          </select>
          <input
            className="input"
            type="number"
            placeholder="Refund window (days)"
            value={form.refund_window_days}
            onChange={(e) => setForm({ ...form, refund_window_days: e.target.value })}
          />
        </div>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <div className="card-header">
          <div>
            <h3>Platform payment settings</h3>
            <p>Keys used for Alumni Global Network platform payouts (5% fees).</p>
          </div>
        </div>
        <div className="payment-settings-grid">
          {(() => {
            const stripe = platformSettings?.stripe || {};
            const paystack = platformSettings?.paystack || {};
            const paypal = platformSettings?.paypal || {};
            const flutterwave = platformSettings?.flutterwave || {};
            return (
              <>
                <div className="card payment-settings-card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">Stripe</div>
                      <div className="card-subtitle">
                        {stripe.secret_key_set ? `Connected (${stripe.secret_key_hint || '••••'})` : 'Not connected'}
                      </div>
                    </div>
                  </div>
                  <div className="card-form">
                    <input className="input" placeholder="Stripe public key" value={platformForm.stripe_public_key} onChange={(e) => setPlatformForm({ ...platformForm, stripe_public_key: e.target.value })} />
                    <input className="input" placeholder="Stripe secret key" value={platformForm.stripe_secret_key} onChange={(e) => setPlatformForm({ ...platformForm, stripe_secret_key: e.target.value })} />
                    <button className="primary" onClick={() => handlePlatformSave('stripe')} disabled={platformSaving.stripe}>
                      {platformSaving.stripe ? 'Saving...' : 'Save Stripe'}
                    </button>
                  </div>
                </div>
                <div className="card payment-settings-card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">Paystack</div>
                      <div className="card-subtitle">
                        {paystack.secret_key_set ? `Connected (${paystack.secret_key_hint || '••••'})` : 'Not connected'}
                      </div>
                    </div>
                  </div>
                  <div className="card-form">
                    <input className="input" placeholder="Paystack public key" value={platformForm.paystack_public_key} onChange={(e) => setPlatformForm({ ...platformForm, paystack_public_key: e.target.value })} />
                    <input className="input" placeholder="Paystack secret key" value={platformForm.paystack_secret_key} onChange={(e) => setPlatformForm({ ...platformForm, paystack_secret_key: e.target.value })} />
                    <button className="primary" onClick={() => handlePlatformSave('paystack')} disabled={platformSaving.paystack}>
                      {platformSaving.paystack ? 'Saving...' : 'Save Paystack'}
                    </button>
                  </div>
                </div>
                <div className="card payment-settings-card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">PayPal</div>
                      <div className="card-subtitle">
                        {paypal.client_secret_set ? `Connected (${paypal.client_secret_hint || '••••'})` : 'Not connected'}
                      </div>
                    </div>
                  </div>
                  <div className="card-form">
                    <input className="input" placeholder="PayPal client ID" value={platformForm.paypal_client_id} onChange={(e) => setPlatformForm({ ...platformForm, paypal_client_id: e.target.value })} />
                    <input className="input" placeholder="PayPal client secret" value={platformForm.paypal_client_secret} onChange={(e) => setPlatformForm({ ...platformForm, paypal_client_secret: e.target.value })} />
                    <button className="primary" onClick={() => handlePlatformSave('paypal')} disabled={platformSaving.paypal}>
                      {platformSaving.paypal ? 'Saving...' : 'Save PayPal'}
                    </button>
                  </div>
                </div>
                <div className="card payment-settings-card">
                  <div className="card-header">
                    <div>
                      <div className="card-title">Flutterwave</div>
                      <div className="card-subtitle">
                        {flutterwave.secret_key_set ? `Connected (${flutterwave.secret_key_hint || '••••'})` : 'Not connected'}
                      </div>
                    </div>
                  </div>
                  <div className="card-form">
                    <input className="input" placeholder="Flutterwave public key" value={platformForm.flutterwave_public_key} onChange={(e) => setPlatformForm({ ...platformForm, flutterwave_public_key: e.target.value })} />
                    <input className="input" placeholder="Flutterwave secret key" value={platformForm.flutterwave_secret_key} onChange={(e) => setPlatformForm({ ...platformForm, flutterwave_secret_key: e.target.value })} />
                    <button className="primary" onClick={() => handlePlatformSave('flutterwave')} disabled={platformSaving.flutterwave}>
                      {platformSaving.flutterwave ? 'Saving...' : 'Save Flutterwave'}
                    </button>
                  </div>
                </div>
              </>
            );
          })()}
        </div>
      </div>
    </div>
  );
}

function SupportTicketModal({ open, ticket, onClose, onSave, currentUserName = 'Support agent', workspaceEntry = {}, onWorkspaceChange }) {
  const [reply, setReply] = useState('');
  const [status, setStatus] = useState('resolved');
  const [internalNote, setInternalNote] = useState('');
  const [assignedToMe, setAssignedToMe] = useState(false);
  const [escalationTarget, setEscalationTarget] = useState('none');

  useEffect(() => {
    if (open && ticket) {
      setReply('');
      setStatus(ticket.status || 'resolved');
      setInternalNote(workspaceEntry?.internal_note || '');
      setAssignedToMe(Boolean(workspaceEntry?.assigned_to_me));
      setEscalationTarget(workspaceEntry?.escalation_target || 'none');
    }
  }, [open, ticket?.id, workspaceEntry?.internal_note, workspaceEntry?.assigned_to_me, workspaceEntry?.escalation_target]);

  if (!open || !ticket) return null;

  const messages = Array.isArray(ticket.messages) ? ticket.messages : [];

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal--large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">Support ticket</div>
        <div className="modal-message">
          <div className="detail-grid">
            <div><strong>Reference</strong><span>{ticket.reference || `#${ticket.id}`}</span></div>
            <div><strong>From</strong><span>{ticket.user?.name || '-'}</span></div>
            <div><strong>Category</strong><span>{ticket.category || '-'}</span></div>
            <div><strong>Priority</strong><span><PriorityPill priority={ticket.priority || 'normal'} /></span></div>
            <div><strong>Status</strong><span>{ticket.status || '-'}</span></div>
          </div>
          <div className="modal-subtitle">Ticket timeline</div>
          <div className="support-history">
            {messages.length > 0 ? messages.map((message, index) => {
              const isAdmin = message?.sender_role === 'admin';
              const name = isAdmin ? (message?.user?.name || 'Support team') : (message?.user?.name || ticket.user?.name || 'User');
              return (
                <div
                  key={message?.id || index}
                  className={`support-history__item${isAdmin ? ' support-history__item--reply' : ''}`}
                >
                  <div className="support-history__label">{isAdmin ? 'Support reply' : 'User reply'}</div>
                  <div className="support-history__meta">
                    {name}
                    {message?.created_at ? ` • ${formatNotificationTime(message.created_at)}` : ''}
                  </div>
                  {index === 0 ? <div className="support-history__title">{ticket.subject || '-'}</div> : null}
                  <div>{message?.message || '-'}</div>
                </div>
              );
            }) : (
              <div className="support-history__item">
                <div className="support-history__label">Original message</div>
                <div className="support-history__meta">{ticket.created_at ? formatNotificationTime(ticket.created_at) : 'Created just now'}</div>
                <div className="support-history__title">{ticket.subject || '-'}</div>
                <div>{ticket.message || '-'}</div>
              </div>
            )}
          </div>
          <div className="modal-subtitle">Admin reply</div>
          <div className="pill-group presets">
            {SUPPORT_CANNED_REPLIES.map((preset) => (
              <button
                key={preset}
                type="button"
                className="pill"
                onClick={() => setReply(preset)}
              >
                Use template
              </button>
            ))}
          </div>
          <textarea
            className="textarea"
            rows="4"
            value={reply}
            onChange={(e) => setReply(e.target.value)}
          />
          <div className="modal-subtitle">Internal notes</div>
          <textarea
            className="textarea"
            rows="3"
            placeholder="Leave internal notes for the support team"
            value={internalNote}
            onChange={(e) => {
              const next = e.target.value;
              setInternalNote(next);
              onWorkspaceChange?.(ticket.id, { internal_note: next });
            }}
          />
          <div className="detail-grid">
            <div>
              <strong>Ownership</strong>
              <label>
                <input
                  type="checkbox"
                  checked={assignedToMe}
                  onChange={(e) => {
                    const next = e.target.checked;
                    setAssignedToMe(next);
                    onWorkspaceChange?.(ticket.id, {
                      assigned_to_me: next,
                      assigned_to_name: next ? currentUserName : '',
                    });
                  }}
                /> Assign to me
              </label>
            </div>
            <div>
              <strong>Escalation lane</strong>
              <select
                className="select"
                value={escalationTarget}
                onChange={(e) => {
                  const next = e.target.value;
                  setEscalationTarget(next);
                  onWorkspaceChange?.(ticket.id, { escalation_target: next });
                }}
              >
                <option value="none">No escalation</option>
                <option value="accounting">Billing / accounting</option>
                <option value="institution">Institution team</option>
                <option value="engineering">Technical escalation</option>
              </select>
            </div>
          </div>
          <div className="modal-subtitle">Update status</div>
          <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
            <option value="dismissed">Dismissed</option>
          </select>
        </div>
        <div className="modal-actions">
          <button className="ghost" onClick={onClose}>Cancel</button>
          <button className="primary" onClick={() => onSave(ticket.id, reply, status, { internal_note: internalNote, assigned_to_me: assignedToMe, escalation_target: escalationTarget })}>Save</button>
        </div>
      </div>
    </div>
  );
}

function SupportQueueView({ scopeLabel, onPendingCountChange, portalMode = 'admin', ticketCategory = '' }) {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('pending');
  const [priorityFilter, setPriorityFilter] = useState('all');
  const [ownershipFilter, setOwnershipFilter] = useState('all');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [previewPost, setPreviewPost] = useState(null);
  const [profileUser, setProfileUser] = useState(null);
  const [profileData, setProfileData] = useState(null);
  const [ticketModal, setTicketModal] = useState({ open: false, ticket: null });
  const [workspaceState, setWorkspaceState] = useState(() => readSupportWorkspaceState());
  const [selectedTicketId, setSelectedTicketId] = useState(null);
  const [newTicket, setNewTicket] = useState({
    subject: '',
    message: '',
    category: portalMode === 'accounting' ? 'billing' : 'general',
    priority: 'normal',
  });
  const [creatingTicket, setCreatingTicket] = useState(false);
  const ticketRows = useMemo(
    () => rows.filter((item) => item?.type === 'support_ticket'),
    [rows]
  );
  const urgentTicketCount = useMemo(
    () => ticketRows.filter((item) => (item?.payload?.priority || '').toString().toLowerCase() === 'urgent').length,
    [ticketRows]
  );
  const uniqueReporterCount = useMemo(
    () => new Set(ticketRows.map((item) => item?.payload?.user?.id).filter(Boolean)).size,
    [ticketRows]
  );
  const selectedTicket = useMemo(
    () => ticketRows.find((item) => item?.payload?.id === selectedTicketId)?.payload || null,
    [ticketRows, selectedTicketId]
  );
  const myAssignedCount = useMemo(
    () => ticketRows.filter((item) => workspaceState[String(item?.payload?.id)]?.assigned_to_me).length,
    [ticketRows, workspaceState]
  );
  const escalatedCount = useMemo(
    () => ticketRows.filter((item) => (workspaceState[String(item?.payload?.id)]?.escalation_target || 'none') !== 'none').length,
    [ticketRows, workspaceState]
  );
  const waitingOnUserCount = useMemo(
    () => ticketRows.filter((item) => {
      const messages = Array.isArray(item?.payload?.messages) ? item.payload.messages : [];
      const latest = messages[messages.length - 1];
      return latest?.sender_role === 'admin' && (item?.payload?.status || '').toString().toLowerCase() === 'pending';
    }).length,
    [ticketRows]
  );
  const slaRiskCount = useMemo(
    () => ticketRows.filter((item) => {
      const createdAt = new Date(item?.payload?.created_at || item?.created_at || 0).getTime();
      return createdAt > 0 && Date.now() - createdAt > 1000 * 60 * 60 * 24 && (item?.payload?.status || '').toString().toLowerCase() === 'pending';
    }).length,
    [ticketRows]
  );

  const heading = portalMode === 'accounting' ? 'Billing Tickets' : portalMode === 'support' ? 'Customer Support Dashboard' : 'Support Queue';
  const subtitle = portalMode === 'accounting'
    ? 'Work through billing-related support issues while keeping payment operations in view.'
    : portalMode === 'support'
    ? 'See support tickets, escalation volume, and the users behind each issue in one place.'
    : 'Review reports and support tickets that need action.';

  const sortQueueRows = (items) => {
    const priorityRank = { urgent: 0, high: 1, normal: 2, low: 3 };
    return [...items].sort((a, b) => {
      const aIsTicket = a?.type === 'support_ticket';
      const bIsTicket = b?.type === 'support_ticket';
      if (status === 'pending' && aIsTicket !== bIsTicket) {
        return aIsTicket ? -1 : 1;
      }
      if (status === 'pending' && aIsTicket && bIsTicket) {
        const aPriority = (a?.payload?.priority || 'normal').toString().toLowerCase();
        const bPriority = (b?.payload?.priority || 'normal').toString().toLowerCase();
        const rankDiff = (priorityRank[aPriority] ?? 99) - (priorityRank[bPriority] ?? 99);
        if (rankDiff !== 0) return rankDiff;
      }
      const aTime = new Date(a?.created_at || a?.payload?.created_at || 0).getTime();
      const bTime = new Date(b?.created_at || b?.payload?.created_at || 0).getTime();
      return bTime - aTime;
    });
  };

  const filterQueueRows = (items) => {
    return items.filter((item) => {
      if (item?.type !== 'support_ticket') {
        return priorityFilter === 'all' && ownershipFilter === 'all';
      }
      const matchesPriority = priorityFilter === 'all'
        ? true
        : (item?.payload?.priority || 'normal').toString().toLowerCase() === priorityFilter;
      const entry = workspaceState[String(item?.payload?.id)] || {};
      const matchesOwnership = ownershipFilter === 'all'
        ? true
        : ownershipFilter === 'mine'
          ? Boolean(entry.assigned_to_me)
          : ownershipFilter === 'escalated'
            ? (entry.escalation_target || 'none') !== 'none'
            : false;
      return matchesPriority && matchesOwnership;
    });
  };

  const loadData = async () => {
    setLoading(true);
    setError('');
      try {
      const data = await fetchSupportQueue({ status, category: ticketCategory, page, perPage: 20 });
      setRows(filterQueueRows(sortQueueRows(data?.data || [])));
      setMeta(data?.meta || null);
      if (status === 'pending') {
        onPendingCountChange?.(Number(data?.meta?.total || 0));
      }
    } catch (err) {
      setError(err.message || 'Failed to load support queue');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData().catch(() => {});
  }, [status, page, priorityFilter, ownershipFilter, ticketCategory, workspaceState]);

  useEffect(() => {
    if (!selectedTicketId && ticketRows.length > 0) {
      setSelectedTicketId(ticketRows[0]?.payload?.id || null);
    }
    if (selectedTicketId && !ticketRows.some((item) => item?.payload?.id === selectedTicketId)) {
      setSelectedTicketId(ticketRows[0]?.payload?.id || null);
    }
  }, [ticketRows, selectedTicketId]);

  const handleWorkspaceChange = (ticketId, patch) => {
    const next = updateSupportWorkspaceEntry(ticketId, patch);
    setWorkspaceState((current) => ({ ...current, [String(ticketId)]: next }));
  };

  async function handleResolve(item, nextStatus) {
    try {
      if (item.type === 'post_report') {
        await resolvePostReport(item.payload.id, nextStatus);
      } else if (item.type === 'support_ticket') {
        await resolveSupportTicket(item.payload.id, nextStatus);
      } else {
        await resolveUserReport(item.payload.id, nextStatus);
      }
      loadData();
    } catch (err) {
      setError(err.message || 'Failed to resolve item');
    }
  }

  async function openProfile(user) {
    if (!user?.id) return;
    setProfileUser(user);
    try {
      const data = await fetchUserProfile(user.id);
      const fetchedUser = data?.user || data || null;
      setProfileUser(fetchedUser || user);
      setProfileData(fetchedUser || null);
    } catch (_) {
      setProfileData(null);
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>{heading}</h2>
          <p>{subtitle}</p>
        </div>
        <div className="panel-actions">
          <select className="select" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
            <option value="dismissed">Dismissed</option>
          </select>
          <select className="select" value={priorityFilter} onChange={(e) => { setPage(1); setPriorityFilter(e.target.value); }}>
            <option value="all">All priorities</option>
            <option value="urgent">Urgent</option>
            <option value="high">High</option>
            <option value="normal">Normal</option>
            <option value="low">Low</option>
          </select>
          <select className="select" value={ownershipFilter} onChange={(e) => { setPage(1); setOwnershipFilter(e.target.value); }}>
            <option value="all">All ownership</option>
            <option value="mine">Assigned to me</option>
            <option value="escalated">Escalated</option>
          </select>
        </div>
      </div>
      <ScopeNote label={scopeLabel} />
      <div className="card">
        <div className="detail-grid">
          <div><strong>Ticket threads</strong><span>{ticketRows.length}</span></div>
          <div><strong>Urgent right now</strong><span>{urgentTicketCount}</span></div>
          <div><strong>Waiting on user</strong><span>{waitingOnUserCount}</span></div>
          <div><strong>Assigned to me</strong><span>{myAssignedCount}</span></div>
          <div><strong>SLA risk</strong><span>{slaRiskCount}</span></div>
          <div><strong>Escalated</strong><span>{escalatedCount}</span></div>
          <div><strong>Users represented</strong><span>{uniqueReporterCount}</span></div>
          <div><strong>Queue total</strong><span>{meta?.total || rows.length}</span></div>
        </div>
      </div>
      <div className="card">
        <h3>{portalMode === 'accounting' ? 'Log a billing issue' : 'Create an internal support ticket'}</h3>
        <div className="card-form support-form">
          <input
            className="input support-subject"
            placeholder="Subject"
            value={newTicket.subject}
            onChange={(e) => setNewTicket({ ...newTicket, subject: e.target.value })}
          />
          <textarea
            className="input support-message"
            rows="3"
            placeholder="Describe the issue"
            value={newTicket.message}
            onChange={(e) => setNewTicket({ ...newTicket, message: e.target.value })}
          />
          <select
            className="select support-category"
            value={newTicket.category}
            onChange={(e) => setNewTicket({ ...newTicket, category: e.target.value })}
            disabled={portalMode === 'accounting'}
          >
            <option value="general">General</option>
            <option value="billing">Billing</option>
            <option value="account">Account</option>
            <option value="content">Content</option>
          </select>
          <select
            className="select support-priority"
            value={newTicket.priority}
            onChange={(e) => setNewTicket({ ...newTicket, priority: e.target.value })}
          >
            <option value="low">Low</option>
            <option value="normal">Normal</option>
            <option value="high">High</option>
            <option value="urgent">Urgent</option>
          </select>
          <button
            className="primary support-submit"
            onClick={async () => {
              if (!newTicket.subject.trim() || !newTicket.message.trim()) {
                setError('Subject and message are required.');
                return;
              }
              setCreatingTicket(true);
              try {
                await createSupportTicket({
                  subject: newTicket.subject.trim(),
                  message: newTicket.message.trim(),
                  category: portalMode === 'accounting' ? 'billing' : newTicket.category,
                  priority: newTicket.priority,
                });
                setNewTicket({ subject: '', message: '', category: portalMode === 'accounting' ? 'billing' : 'general', priority: 'normal' });
                await loadData();
              } catch (err) {
                setError(err.message || 'Failed to submit ticket');
              } finally {
                setCreatingTicket(false);
              }
            }}
            disabled={creatingTicket}
          >
            {creatingTicket ? 'Submitting...' : 'Submit ticket'}
          </button>
        </div>
      </div>
      {error && <div className="alert">{error}</div>}
      <div className="support-workspace">
      <div className="card support-table-card">
        <div className="support-table-scroll">
        <div className="table table--wide support-table-section support-table--head-centered support-table--row-centered">
          <div className="table-row table-row--head">
            <div>Type</div>
            <div>Reference</div>
            <div>Reporter</div>
            <div>Subject</div>
            <div>Message</div>
            <div>Priority</div>
            <div>Status</div>
            <div>Action</div>
          </div>
          {loading ? (
            <div className="table-row"><div>Loading...</div></div>
          ) : rows.length === 0 ? (
            <div className="table-row"><div>No queue items.</div></div>
          ) : (
            rows.map((item) => {
              const payload = item.payload;
              const isPost = item.type === 'post_report';
              const isTicket = item.type === 'support_ticket';
              const reporter = isTicket ? payload.user : payload.reporter;
              const subject = isPost ? payload.post?.user : isTicket ? payload.subject : payload.reported_user;
              const lastThreadMessage = isTicket && Array.isArray(payload.messages) && payload.messages.length
                ? payload.messages[payload.messages.length - 1]?.message
                : null;
              const message = isTicket ? (lastThreadMessage || payload.message) : payload.reason;
              const priority = isTicket ? payload.priority : null;
              return (
                <div
                  className={`table-row${isTicket ? ` support-ticket-row support-ticket-row--${(priority || 'normal').toString().toLowerCase()}` : ''}`}
                  key={`${item.type}-${payload.id}`}
                  onClick={isTicket ? () => setSelectedTicketId(payload.id) : undefined}
                >
                  <div>{isPost ? 'Post report' : isTicket ? 'Support ticket' : 'User report'}</div>
                  <div>{isTicket ? (payload.reference || `#${payload.id}`) : <span className="support-table-muted">—</span>}</div>
                  <div className="link" onClick={() => openProfile(reporter)}>{reporter?.name || '-'}</div>
                  <div className={isTicket ? '' : 'link'} onClick={!isTicket ? () => openProfile(subject) : undefined}>
                    {isTicket ? (payload.subject || '-') : (subject?.name || '-')}
                  </div>
                  <div>{message || '-'}</div>
                  <div>{isTicket ? <PriorityPill priority={priority} /> : <span className="support-table-muted">—</span>}</div>
                  <div><StatusPill status={payload.status} /></div>
                  <div className="actions">
                    {isPost && (
                      <button className="ghost" onClick={() => setPreviewPost(payload.post)}>View post</button>
                    )}
                    {isTicket && (
                      <button className="ghost" onClick={() => setTicketModal({ open: true, ticket: payload })}>
                        Reply
                      </button>
                    )}
                    {isTicket && (
                      <button
                        className="ghost"
                        onClick={() => handleWorkspaceChange(payload.id, {
                          assigned_to_me: !workspaceState[String(payload.id)]?.assigned_to_me,
                          assigned_to_name: !workspaceState[String(payload.id)]?.assigned_to_me ? 'Me' : '',
                        })}
                      >
                        {workspaceState[String(payload.id)]?.assigned_to_me ? 'Unassign' : 'Assign'}
                      </button>
                    )}
                    <button className="ghost" onClick={() => handleResolve(item, 'resolved')}>Resolve</button>
                    <button className="ghost" onClick={() => handleResolve(item, 'dismissed')}>Dismiss</button>
                  </div>
                </div>
              );
            })
          )}
        </div>
        </div>
        <div className="pagination">
          <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
          <span>Page {page}</span>
          <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
        </div>
      </div>
      {selectedTicket && (
        <div className="card support-context-card">
          <div className="card-header">
            <div>
              <h3>Customer context</h3>
              <p>Keep the user, thread, and escalation state beside the queue.</p>
            </div>
          </div>
          <div className="detail-grid">
            <div><strong>User</strong><span>{selectedTicket.user?.name || '-'}</span></div>
            <div><strong>Email</strong><span>{selectedTicket.user?.email || '-'}</span></div>
            <div><strong>Institution</strong><span>{selectedTicket.institution?.name || '-'}</span></div>
            <div><strong>Priority</strong><span>{selectedTicket.priority || '-'}</span></div>
            <div><strong>Assigned</strong><span>{workspaceState[String(selectedTicket.id)]?.assigned_to_me ? 'Assigned to me' : 'Unassigned'}</span></div>
            <div><strong>Escalation</strong><span>{workspaceState[String(selectedTicket.id)]?.escalation_target || 'none'}</span></div>
          </div>
          <div className="modal-subtitle">Internal notes</div>
          <textarea
            className="textarea"
            rows="4"
            placeholder="Capture internal notes, diagnostics, or next steps"
            value={workspaceState[String(selectedTicket.id)]?.internal_note || ''}
            onChange={(e) => handleWorkspaceChange(selectedTicket.id, { internal_note: e.target.value })}
          />
          <div className="pill-group presets">
            <button className="pill" type="button" onClick={() => handleWorkspaceChange(selectedTicket.id, { escalation_target: 'accounting' })}>Send to accounting</button>
            <button className="pill" type="button" onClick={() => handleWorkspaceChange(selectedTicket.id, { escalation_target: 'institution' })}>Send to institution</button>
            <button className="pill" type="button" onClick={() => handleWorkspaceChange(selectedTicket.id, { escalation_target: 'engineering' })}>Send to engineering</button>
          </div>
          <div className="modal-subtitle">Recent messages</div>
          <div className="support-history">
            {(selectedTicket.messages || []).slice(-4).map((message, index) => (
              <div key={message?.id || index} className={`support-history__item${message?.sender_role === 'admin' ? ' support-history__item--reply' : ''}`}>
                <div className="support-history__label">{message?.sender_role === 'admin' ? 'Support' : 'User'}</div>
                <div className="support-history__meta">{message?.user?.name || 'Unknown'}{message?.created_at ? ` • ${formatNotificationTime(message.created_at)}` : ''}</div>
                <div>{message?.message || '-'}</div>
              </div>
            ))}
          </div>
        </div>
      )}
      </div>
      <PostPreviewModal open={!!previewPost} post={previewPost} onClose={() => setPreviewPost(null)} />
      <UserProfileModal
        open={!!profileUser}
        user={profileUser}
        profile={profileData?.profile}
        onClose={() => { setProfileUser(null); setProfileData(null); }}
        onSaved={() => { setProfileUser(null); setProfileData(null); }}
      />
      <SupportTicketModal
        open={ticketModal.open}
        ticket={ticketModal.ticket}
        currentUserName={portalMode === 'accounting' ? 'Accounting team' : 'Customer support'}
        workspaceEntry={ticketModal.ticket ? workspaceState[String(ticketModal.ticket.id)] || {} : {}}
        onWorkspaceChange={handleWorkspaceChange}
        onClose={() => setTicketModal({ open: false, ticket: null })}
        onSave={async (ticketId, reply, status, localState) => {
          try {
            const currentStatus = (ticketModal.ticket?.status || '').toString().toLowerCase();
            const nextReply = reply.trim();
            if (localState) {
              handleWorkspaceChange(ticketId, localState);
            }
            if (nextReply) {
              await replySupportTicket(ticketId, nextReply);
            }
            if (!nextReply || (status && status.toLowerCase() !== currentStatus)) {
              await resolveSupportTicket(ticketId, status, nextReply || null);
            }
            setTicketModal({ open: false, ticket: null });
            await loadData();
          } catch (err) {
            setError(err.message || 'Failed to update ticket');
          }
        }}
      />
    </div>
  );
}

function InstitutionViewNav() {
  const tabs = [
    { to: '/super/institution-view/dashboard', label: 'Dashboard' },
        { to: '/super/institution-view/requests', label: 'Join Requests' },
        { to: '/super/institution-view/jobs', label: 'Jobs' },
        { to: '/super/institution-view/events', label: 'Events' },
        { to: '/super/institution-view/donations', label: 'Donations' },
        { to: '/super/institution-view/payment-settings', label: 'Payment Settings' },
        { to: '/super/institution-view/analytics', label: 'Analytics' },
      ];

  return (
    <div className="subnav">
      {tabs.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) => `subnav-item${isActive ? ' subnav-item--active' : ''}`}
        >
          {tab.label}
        </NavLink>
      ))}
    </div>
  );
}

function SuperInstitutionsPage() {
  const [refreshKey, setRefreshKey] = useState(0);
  return (
    <div className="stack">
      <MonetizationQuickCard />
      <InstitutionCreateCard onCreated={() => setRefreshKey((k) => k + 1)} />
      <InstitutionBulkImportCard onImported={() => setRefreshKey((k) => k + 1)} />
      <InstitutionsView refreshKey={refreshKey} />
    </div>
  );
}

function MonetizationQuickCard() {
  const [settings, setSettings] = useState(null);
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    setLoading(true);
    fetchSystemSettings()
      .then((data) => {
        const list = data?.data || [];
        const map = list.reduce((acc, item) => {
          acc[item.key] = item.value;
          return acc;
        }, {});
        setSettings(map);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const feeEnabled = settings?.platform_fee_enabled !== false;
  const feePercent = settings?.platform_fee_percent ?? 0;
  const currency = settings?.default_currency || 'GHS';

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <h3>Monetization</h3>
          <p>Platform fees and defaults at a glance.</p>
        </div>
        <button className="ghost" onClick={() => navigate('/super/monetization')}>
          Manage
        </button>
      </div>
      <div className="card-form">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : (
          <>
            <div className="pill-group">
              <span className="pill">{feeEnabled ? 'Fee enabled' : 'Fee disabled'}</span>
              <span className="pill">Fee {feePercent}%</span>
              <span className="pill">Default {currency}</span>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function EventsPage({ institutionId, allowHardDelete, currentUser }) {
  const [refreshKey, setRefreshKey] = useState(0);
  return (
    <div className="stack">
      <CreateEventCard institutionId={institutionId} onCreated={() => setRefreshKey((k) => k + 1)} />
      <EventsView institutionId={institutionId} refreshKey={refreshKey} allowHardDelete={allowHardDelete} currentUser={currentUser} />
    </div>
  );
}

function DonationsPage({ institutionId, allowHardDelete }) {
  const [refreshKey, setRefreshKey] = useState(0);
  return (
    <div className="stack">
      <CreateDonationCard institutionId={institutionId} onCreated={() => setRefreshKey((k) => k + 1)} />
      <DonationsView institutionId={institutionId} refreshKey={refreshKey} allowHardDelete={allowHardDelete} />
    </div>
  );
}

function InstitutionProfileView({ institutionId }) {
  const [form, setForm] = useState({
    name: '',
    website: '',
    email: '',
    phone: '',
    location: '',
    address: '',
    motto: '',
    logo_url: '',
    banner_url: '',
    description: '',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState({ stripe: false, paystack: false, paypal: false });
  const [error, setError] = useState('');
  const [saved, setSaved] = useState('');
  const [uploading, setUploading] = useState({ logo: false, banner: false });
  const MAX_UPLOAD_SIZE = 2 * 1024 * 1024;
  const ALLOWED_TYPES = ['image/png', 'image/jpeg'];

  async function handleUpload(type, file) {
    if (!file) return;
    if (!ALLOWED_TYPES.includes(file.type)) {
      setError('Only PNG or JPG images are allowed.');
      return;
    }
    if (file.size > MAX_UPLOAD_SIZE) {
      setError('File is too large. Max size is 2MB.');
      return;
    }
    setUploading((prev) => ({ ...prev, [type]: true }));
    try {
      const data = await uploadAdminMedia(file);
      if (data?.url) {
        setForm((prev) => ({
          ...prev,
          ...(type === 'logo' ? { logo_url: data.url } : { banner_url: data.url }),
        }));
      }
    } catch (err) {
      setError(err.message || 'Upload failed');
    } finally {
      setUploading((prev) => ({ ...prev, [type]: false }));
    }
  }

  useEffect(() => {
    setLoading(true);
    setError('');
    fetchMyInstitutionProfile()
      .then((res) => {
        const inst = res?.institution || {};
        setForm({
          name: inst.name || '',
          website: inst.website || '',
          email: inst.email || '',
          phone: inst.phone || '',
          location: inst.location || '',
          address: inst.address || '',
          motto: inst.motto || '',
          logo_url: inst.logo_url || '',
          banner_url: inst.banner_url || '',
          description: inst.description || '',
        });
      })
      .catch((err) => setError(err.message || 'Failed to load institution'))
      .finally(() => setLoading(false));
  }, [institutionId]);

  async function handleSave() {
    setSaving(true);
    setError('');
    setSaved(false);
    try {
      await updateMyInstitutionProfile(form);
      setSaved(true);
    } catch (err) {
      setError(err.message || 'Failed to update institution');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Institution profile</h2>
          <p>Manage your school profile and public details.</p>
        </div>
      </div>
      {error && <div className="alert">{error}</div>}
      {saved && <div className="alert success">Profile updated.</div>}
      {loading ? (
        <div className="table-row"><div>Loading...</div></div>
      ) : (
        <div className="card">
          <div className="card-form card-form--wide">
            <input className="input" placeholder="School name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            <input className="input" placeholder="Website" value={form.website} onChange={(e) => setForm({ ...form, website: e.target.value })} />
            <input className="input" placeholder="Email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            <input className="input" placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            <input className="input" placeholder="Location" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
            <input className="input" placeholder="Address" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            <input className="input" placeholder="Motto" value={form.motto} onChange={(e) => setForm({ ...form, motto: e.target.value })} />
            <div className="file-row">
              <input className="input" placeholder="Logo" value={form.logo_url} readOnly />
              <div className="upload-thumb">
                {form.logo_url ? <img src={resolveMediaUrl(form.logo_url)} alt="Logo preview" /> : 'Logo'}
              </div>
              <label className="file-upload">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    e.target.value = '';
                    handleUpload('logo', file);
                  }}
                />
                {uploading.logo ? 'Uploading...' : 'Upload logo'}
              </label>
            </div>
            <div className="file-row">
              <input className="input" placeholder="Banner" value={form.banner_url} readOnly />
              <div className="upload-thumb">
                {form.banner_url ? <img src={resolveMediaUrl(form.banner_url)} alt="Banner preview" /> : 'Banner'}
              </div>
              <label className="file-upload">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    e.target.value = '';
                    handleUpload('banner', file);
                  }}
                />
                {uploading.banner ? 'Uploading...' : 'Upload banner'}
              </label>
            </div>
          </div>
          <div className="brand-preview">
            <div className="brand-badge">
              {form.logo_url ? <img src={resolveMediaUrl(form.logo_url)} alt="Logo preview" /> : <span>Logo</span>}
            </div>
            <div className="brand-meta">
              <div className="brand-title">Logo</div>
              <div className="brand-subtitle">{form.logo_url ? 'Uploaded' : 'No logo yet'}</div>
            </div>
          </div>
          <div className="brand-preview">
            <div className="brand-badge" style={{ width: 140, height: 72 }}>
              {form.banner_url ? <img src={resolveMediaUrl(form.banner_url)} alt="Banner preview" /> : <span>Banner</span>}
            </div>
            <div className="brand-meta">
              <div className="brand-title">Banner</div>
              <div className="brand-subtitle">{form.banner_url ? 'Uploaded' : 'No banner yet'}</div>
            </div>
          </div>
          <textarea className="textarea" rows="5" placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          <div className="modal-actions">
            <button className="primary" onClick={handleSave} disabled={saving}>
              {saving ? 'Saving...' : 'Save profile'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function PaymentSettingsView({ institutionId, isSuper, scopeLabel }) {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);
  const [settings, setSettings] = useState(null);
  const [form, setForm] = useState({
    stripe_public_key: '',
    stripe_secret_key: '',
    paystack_public_key: '',
    paystack_secret_key: '',
    paypal_client_id: '',
    paypal_client_secret: '',
    flutterwave_public_key: '',
    flutterwave_secret_key: '',
  });
  const [paypalMode, setPaypalMode] = useState('live');

  const canLoad = !isSuper || !!institutionId;

  const loadSettings = async () => {
    if (!canLoad) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError('');
    try {
      const data = isSuper
        ? await fetchInstitutionPaymentSettings(institutionId)
        : await fetchMyPaymentSettings();
      setSettings(data?.settings || null);
      const nextMode = data?.settings?.paypal?.mode || 'live';
      setPaypalMode(nextMode);
    } catch (err) {
      setError(err.message || 'Failed to load payment settings');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSettings().catch(() => {});
  }, [institutionId]);

  async function handleSave(provider) {
    setError('');
    setSaved('');

    const payload = {};
    if (provider === 'stripe') {
      if (form.stripe_public_key?.trim()) payload.stripe_public_key = form.stripe_public_key.trim();
      if (form.stripe_secret_key?.trim()) payload.stripe_secret_key = form.stripe_secret_key.trim();
    }
    if (provider === 'paystack') {
      if (form.paystack_public_key?.trim()) payload.paystack_public_key = form.paystack_public_key.trim();
      if (form.paystack_secret_key?.trim()) payload.paystack_secret_key = form.paystack_secret_key.trim();
    }
    if (provider === 'paypal') {
      if (form.paypal_client_id?.trim()) payload.paypal_client_id = form.paypal_client_id.trim();
      if (form.paypal_client_secret?.trim()) payload.paypal_client_secret = form.paypal_client_secret.trim();
      if (paypalMode) payload.paypal_mode = paypalMode;
    }
    if (provider === 'flutterwave') {
      if (form.flutterwave_public_key?.trim()) payload.flutterwave_public_key = form.flutterwave_public_key.trim();
      if (form.flutterwave_secret_key?.trim()) payload.flutterwave_secret_key = form.flutterwave_secret_key.trim();
    }

    if (Object.keys(payload).length === 0) {
      setError('Enter at least one key to update.');
      return;
    }

    setSaving((prev) => ({ ...prev, [provider]: true }));
    try {
      if (isSuper) {
        await updateInstitutionPaymentSettings(institutionId, payload);
      } else {
        await updateMyPaymentSettings(payload);
      }
      setForm((prev) => ({
        ...prev,
        ...(provider === 'stripe' ? { stripe_public_key: '', stripe_secret_key: '' } : {}),
        ...(provider === 'paystack' ? { paystack_public_key: '', paystack_secret_key: '' } : {}),
        ...(provider === 'paypal' ? { paypal_client_id: '', paypal_client_secret: '' } : {}),
        ...(provider === 'flutterwave' ? { flutterwave_public_key: '', flutterwave_secret_key: '' } : {}),
      }));
      await loadSettings();
      setSaved(`${provider} saved`);
    } catch (err) {
      const details = err?.data?.errors
        ? Object.values(err.data.errors).flat()[0]
        : null;
      setError(details || err.message || 'Failed to update payment settings');
    } finally {
      setSaving((prev) => ({ ...prev, [provider]: false }));
    }
  }

  const stripe = settings?.stripe || {};
  const paystack = settings?.paystack || {};
  const paypal = settings?.paypal || {};
  const flutterwave = settings?.flutterwave || {};
  const paypalModeLabel = paypal?.mode === 'sandbox' ? 'Sandbox' : 'Live';

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Payment settings</h2>
          <p>Connect Stripe, Paystack, PayPal, or Flutterwave to receive donations directly.</p>
          {scopeLabel && <div className="chip">Scoped to: {scopeLabel}</div>}
        </div>
      </div>
      {!canLoad ? (
        <div className="alert">Select an institution to manage payment settings.</div>
      ) : (
        <>
          {error && <div className="alert">{error}</div>}
          {saved && <div className="alert success">Settings updated: {saved}</div>}
          {loading ? (
            <div className="table-row"><div>Loading...</div></div>
          ) : (
            <div className="payment-settings-grid">
              <div className="card payment-settings-card">
                <div className="card-header">
                  <div>
                    <div className="card-title">Stripe</div>
                    <div className="card-subtitle">
                      {stripe.secret_key_set ? `Connected (${stripe.secret_key_hint || '••••'})` : 'Not connected'}
                    </div>
                  </div>
                </div>
                <div className="card-form">
                  <input className="input" placeholder="Stripe public key" value={form.stripe_public_key} onChange={(e) => setForm({ ...form, stripe_public_key: e.target.value })} />
                  <input className="input" placeholder="Stripe secret key" value={form.stripe_secret_key} onChange={(e) => setForm({ ...form, stripe_secret_key: e.target.value })} />
                  <button className="primary" onClick={() => handleSave('stripe')} disabled={saving.stripe || loading || !canLoad}>
                    {saving.stripe ? 'Saving...' : 'Save Stripe'}
                  </button>
                </div>
              </div>
              <div className="card payment-settings-card">
                <div className="card-header">
                  <div>
                    <div className="card-title">Paystack</div>
                    <div className="card-subtitle">
                      {paystack.secret_key_set ? `Connected (${paystack.secret_key_hint || '••••'})` : 'Not connected'}
                    </div>
                  </div>
                </div>
                <div className="card-form">
                  <input className="input" placeholder="Paystack public key" value={form.paystack_public_key} onChange={(e) => setForm({ ...form, paystack_public_key: e.target.value })} />
                  <input className="input" placeholder="Paystack secret key" value={form.paystack_secret_key} onChange={(e) => setForm({ ...form, paystack_secret_key: e.target.value })} />
                  <button className="primary" onClick={() => handleSave('paystack')} disabled={saving.paystack || loading || !canLoad}>
                    {saving.paystack ? 'Saving...' : 'Save Paystack'}
                  </button>
                </div>
              </div>
              <div className="card payment-settings-card">
                <div className="card-header">
                  <div>
                    <div className="card-title">PayPal</div>
                    <div className="card-subtitle">
                      {paypal.client_secret_set ? `Connected (${paypal.client_secret_hint || '••••'})` : 'Not connected'}
                      <span className="badge" style={{ marginLeft: 8 }}>{paypalModeLabel}</span>
                    </div>
                  </div>
                </div>
                <div className="card-form">
                  <input className="input" placeholder="PayPal client ID" value={form.paypal_client_id} onChange={(e) => setForm({ ...form, paypal_client_id: e.target.value })} />
                  <input className="input" placeholder="PayPal client secret" value={form.paypal_client_secret} onChange={(e) => setForm({ ...form, paypal_client_secret: e.target.value })} />
                  <select className="select" value={paypalMode} onChange={(e) => setPaypalMode(e.target.value)}>
                    <option value="live">Live mode</option>
                    <option value="sandbox">Sandbox mode</option>
                  </select>
                  <button className="primary" onClick={() => handleSave('paypal')} disabled={saving.paypal || loading || !canLoad}>
                    {saving.paypal ? 'Saving...' : 'Save PayPal'}
                  </button>
                </div>
              </div>
              <div className="card payment-settings-card">
                <div className="card-header">
                  <div>
                    <div className="card-title">Flutterwave</div>
                    <div className="card-subtitle">
                      {flutterwave.secret_key_set ? `Connected (${flutterwave.secret_key_hint || '••••'})` : 'Not connected'}
                    </div>
                  </div>
                </div>
                <div className="card-form">
                  <input className="input" placeholder="Flutterwave public key" value={form.flutterwave_public_key} onChange={(e) => setForm({ ...form, flutterwave_public_key: e.target.value })} />
                  <input className="input" placeholder="Flutterwave secret key" value={form.flutterwave_secret_key} onChange={(e) => setForm({ ...form, flutterwave_secret_key: e.target.value })} />
                  <button className="primary" onClick={() => handleSave('flutterwave')} disabled={saving.flutterwave || loading || !canLoad}>
                    {saving.flutterwave ? 'Saving...' : 'Save Flutterwave'}
                  </button>
                </div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function NewsletterView() {
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState(null);
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('subscribed');
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [launchDate, setLaunchDate] = useState('');
  const [lastSentAt, setLastSentAt] = useState('');
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [sending, setSending] = useState(false);
  const [sendResult, setSendResult] = useState('');
  const [testEmail, setTestEmail] = useState('');
  const [testing, setTesting] = useState(false);

  const loadTemplate = async () => {
    try {
      const data = await fetchSystemSettings();
      const list = data?.data || [];
      const map = list.reduce((acc, item) => {
        acc[item.key] = item.value;
        return acc;
      }, {});
      setSubject(map.newsletter_launch_subject || 'Alumni Global Network is launching soon');
      setBody(map.newsletter_launch_body || 'Thanks for joining our waitlist. We will be launching soon. Stay tuned.');
      setLaunchDate(map.newsletter_launch_date ? new Date(map.newsletter_launch_date).toISOString().slice(0, 16) : '');
      setLastSentAt(map.newsletter_launch_sent_at || '');
    } catch (_) {
      setSubject('Alumni Global Network is launching soon');
      setBody('Thanks for joining our waitlist. We will be launching soon. Stay tuned.');
    }
  };

  const loadSubscribers = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchNewsletterSubscribers({ status, q: query, page, perPage: 25 });
      setRows(data?.data || []);
      setMeta(data?.meta || null);
    } catch (err) {
      setError(err.message || 'Failed to load subscribers');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTemplate().catch(() => {});
  }, []);

  useEffect(() => {
    loadSubscribers().catch(() => {});
  }, [page, status]);

  async function handleSaveTemplate() {
    setSaving(true);
    setSaved(false);
    setError('');
    try {
      await updateSystemSettings({
        newsletter_launch_subject: subject || null,
        newsletter_launch_body: body || null,
        newsletter_launch_date: launchDate ? new Date(launchDate).toISOString() : null,
      });
      setSaved(true);
    } catch (err) {
      setError(err.message || 'Failed to save template');
    } finally {
      setSaving(false);
    }
  }

  async function handleSend() {
    setSending(true);
    setSendResult('');
    setError('');
    try {
      const res = await sendNewsletterLaunch({ subject, body });
      setSendResult(`Sent to ${res?.sent || 0} subscribers.`);
      loadSubscribers().catch(() => {});
    } catch (err) {
      setError(err.message || 'Failed to send newsletter');
    } finally {
      setSending(false);
    }
  }

  async function handleSendTest() {
    setTesting(true);
    setSendResult('');
    setError('');
    try {
      await sendTestEmail(testEmail || undefined);
      setSendResult('Test email sent.');
    } catch (err) {
      setError(err.message || 'Failed to send test email');
    } finally {
      setTesting(false);
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Newsletter</h2>
          <p>Subscribers from the public website join form.</p>
        </div>
      </div>

      {error && <div className="alert">{error}</div>}
      {saved && <div className="alert success">Template saved.</div>}
      {sendResult && <div className="alert success">{sendResult}</div>}

      <div className="card">
        <div className="card-title-row">
          <div>
            <h3>Launch email</h3>
            <p>Use this message for the launch announcement.</p>
          </div>
          <div className="panel-actions">
            <button className="ghost" onClick={handleSaveTemplate} disabled={saving}>
              {saving ? 'Saving...' : 'Save template'}
            </button>
            <button className="ghost" onClick={handleSendTest} disabled={testing}>
              {testing ? 'Sending test...' : 'Send test email'}
            </button>
            <button className="primary" onClick={handleSend} disabled={sending}>
              {sending ? 'Sending...' : 'Send launch email'}
            </button>
          </div>
        </div>
        <div className="card-form card-form--wide">
          <input
            className="input"
            placeholder="Test email (leave empty for your admin email)"
            value={testEmail}
            onChange={(e) => setTestEmail(e.target.value)}
          />
          <input className="input" placeholder="Subject" value={subject} onChange={(e) => setSubject(e.target.value)} />
          <input
            className="input"
            type="datetime-local"
            value={launchDate}
            onChange={(e) => setLaunchDate(e.target.value)}
          />
          <textarea className="input" rows="4" placeholder="Email body" value={body} onChange={(e) => setBody(e.target.value)} />
          {lastSentAt && (
            <div className="helper-text">Last sent: {new Date(lastSentAt).toLocaleString()}</div>
          )}
        </div>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        <div className="card-title-row">
          <div>
            <h3>Subscribers</h3>
            <p>Total subscribers: {meta?.total || rows.length}</p>
          </div>
          <div className="panel-actions">
            <input
              className="input"
              placeholder="Search email"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  setPage(1);
                  loadSubscribers().catch(() => {});
                }
              }}
            />
            <select className="select" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
              <option value="">All</option>
              <option value="subscribed">Subscribed</option>
              <option value="unsubscribed">Unsubscribed</option>
            </select>
            <button className="ghost" onClick={() => { setPage(1); loadSubscribers().catch(() => {}); }}>
              Apply
            </button>
            <button
              className="ghost"
              onClick={async () => {
                try {
                  const blob = await downloadNewsletterCsv();
                  const url = URL.createObjectURL(blob);
                  const link = document.createElement('a');
                  link.href = url;
                  link.setAttribute('download', 'newsletter-subscribers.csv');
                  document.body.appendChild(link);
                  link.click();
                  document.body.removeChild(link);
                } catch (err) {
                  setError(err.message || 'Failed to download CSV');
                }
              }}
            >
              Export CSV
            </button>
          </div>
        </div>
        <div className="table table--wide support-table-section support-table--head-centered support-table--row-centered">
          <div className="table-row table-row--head">
            <div>Email</div>
            <div>Status</div>
            <div>Source</div>
            <div>Subscribed</div>
            <div>Last sent</div>
          </div>
          {loading ? (
            <div className="table-row"><div>Loading...</div></div>
          ) : rows.length === 0 ? (
            <div className="table-row"><div>No subscribers yet.</div></div>
          ) : (
            rows.map((row) => (
              <div className="table-row" key={row.id}>
                <div>{row.email}</div>
                <div>{row.status || '-'}</div>
                <div>{row.source || '-'}</div>
                <div>{row.subscribed_at ? new Date(row.subscribed_at).toLocaleString() : '-'}</div>
                <div>{row.last_sent_at ? new Date(row.last_sent_at).toLocaleString() : '-'}</div>
              </div>
            ))
          )}
        </div>
        <div className="pagination">
          <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Prev</button>
          <span>Page {page}</span>
          <button className="ghost" onClick={() => setPage((p) => p + 1)} disabled={meta && page >= (meta?.last_page || page)}>Next</button>
        </div>
      </div>
    </div>
  );
}

function BroadcastNotificationsView() {
  const [topic, setTopic] = useState('general');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState('broadcast');
  const [scheduledFor, setScheduledFor] = useState('');
  const [createInApp, setCreateInApp] = useState(true);
  const [dataInput, setDataInput] = useState('{\n  "screen": "notifications"\n}');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState(null);

  async function handleSend() {
    setSending(true);
    setError('');
    setResult(null);

    let parsedData = {};
    if (dataInput.trim()) {
      try {
        parsedData = JSON.parse(dataInput);
      } catch (_) {
        setError('Data payload must be valid JSON.');
        setSending(false);
        return;
      }
    }

    try {
      const res = await sendBroadcastNotification({
        topic,
        title,
        body: body || null,
        type,
        scheduled_for: scheduledFor || null,
        create_in_app: createInApp,
        data: parsedData,
      });
      setResult(res || null);
    } catch (err) {
      setError(err.message || 'Failed to send broadcast');
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2>Broadcast Notifications</h2>
          <p>Send Firebase topic notifications and matching in-app notifications from the super admin dashboard.</p>
        </div>
      </div>

      {error && <div className="alert">{error}</div>}
      {result && (
        <div className="alert success">
          {result?.scheduled ? 'Broadcast scheduled successfully.' : 'Broadcast sent successfully.'}
        </div>
      )}

      <div className="card">
        <div className="card-title-row">
          <div>
            <h3>Compose broadcast</h3>
            <p>`general` reaches all subscribed app users. Role topics are filtered by app account type.</p>
          </div>
          <div className="panel-actions">
            <button className="primary" onClick={handleSend} disabled={sending || !title.trim()}>
              {sending ? 'Sending...' : 'Send broadcast'}
            </button>
          </div>
        </div>

        <div className="card-form card-form--wide">
          <select className="select" value={topic} onChange={(e) => setTopic(e.target.value)}>
            <option value="general">General</option>
            <option value="alumni">Alumni</option>
            <option value="school_admin">School Admin</option>
            <option value="super_admin">Super Admin</option>
          </select>
          <input className="input" placeholder="Notification title" value={title} onChange={(e) => setTitle(e.target.value)} />
          <input className="input" placeholder="Notification type" value={type} onChange={(e) => setType(e.target.value)} />
          <input
            className="input"
            type="datetime-local"
            value={scheduledFor}
            onChange={(e) => setScheduledFor(e.target.value)}
          />
          <textarea className="input" rows="4" placeholder="Optional notification body" value={body} onChange={(e) => setBody(e.target.value)} />
          <textarea
            className="input"
            rows="8"
            placeholder="Optional JSON data payload"
            value={dataInput}
            onChange={(e) => setDataInput(e.target.value)}
          />
          <label className="checkbox">
            <input type="checkbox" checked={createInApp} onChange={(e) => setCreateInApp(e.target.checked)} />
            Create matching in-app notifications
          </label>
        </div>
      </div>

      <div className="grid-2" style={{ marginTop: 16 }}>
        <div className="metric">
          <span className="metric-label">Topic</span>
          <strong>{topic}</strong>
          <small>Firebase audience target</small>
        </div>
        <div className="metric">
          <span className="metric-label">In-app creation</span>
          <strong>{createInApp ? 'Enabled' : 'Disabled'}</strong>
          <small>Creates database notifications after push send</small>
        </div>
        <div className="metric">
          <span className="metric-label">Delivery</span>
          <strong>{scheduledFor ? 'Scheduled' : 'Immediate'}</strong>
          <small>{scheduledFor || 'Sends immediately when submitted'}</small>
        </div>
      </div>

      {result && (
        <div className="card" style={{ marginTop: 16 }}>
          <div className="card-title-row">
            <div>
              <h3>Last response</h3>
              <p>Use this to confirm Firebase accepted the message and how many in-app rows were created.</p>
            </div>
          </div>
          <div className="grid-2">
            <div className="metric">
              <span className="metric-label">Firebase message</span>
              <strong>{result?.firebase?.name || (result?.scheduled ? 'Queued' : 'Accepted')}</strong>
              <small>{result?.scheduled ? 'Scheduled broadcast id' : 'FCM v1 response id'}</small>
            </div>
            <div className="metric">
              <span className="metric-label">In-app notifications</span>
              <strong>{result?.in_app_notifications_created ?? 0}</strong>
              <small>{result?.scheduled ? 'Will be created at send time' : 'Rows written to app notifications'}</small>
            </div>
          </div>
          <pre className="code-block">{JSON.stringify(result, null, 2)}</pre>
        </div>
      )}
    </div>
  );
}

function AdminLayout({ user, onLogout, institutions, viewAsInstitutionId, onViewAsChange, roleCatalog }) {
  const role = user?.role;
  const isSuper = role === 'super_admin';
  const navigate = useNavigate();
  const location = useLocation();
  const [lastRefresh, setLastRefresh] = useState(new Date());
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [notificationItems, setNotificationItems] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [supportQueueCount, setSupportQueueCount] = useState(0);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [notificationActionBusy, setNotificationActionBusy] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [browserNotificationState, setBrowserNotificationState] = useState(() => {
    const { config } = getFirebaseWebConfig();
    if (!config) return 'missing-config';
    if (typeof window === 'undefined' || !('Notification' in window)) return 'unsupported';
    return window.Notification.permission;
  });
  const [notificationSoundEnabled, setNotificationSoundEnabled] = useState(() => {
    if (typeof window === 'undefined') return true;
    const raw = window.localStorage.getItem('admin_notification_sound_enabled');
    if (raw == null) return true;
    return raw === 'true';
  });
  const notificationPollRef = useRef(null);
  const notificationAudioRef = useRef(null);
  const lastUnreadRef = useRef(0);
  const unreadPrimedRef = useRef(false);
  const notificationPollingRef = useRef(false);
  const knownNotificationIdsRef = useRef(new Set());
  const notificationMenuRef = useRef(null);
  const supportQueuePollingRef = useRef(false);

  useEffect(() => {
    setLastRefresh(new Date());
  }, [location.pathname]);

  useEffect(() => {
    setMobileNavOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    window.localStorage.setItem('admin_notification_sound_enabled', String(notificationSoundEnabled));
  }, [notificationSoundEnabled]);

  useEffect(() => {
    if (!notificationsOpen) return;
    const handlePointerDown = (event) => {
      if (notificationMenuRef.current && !notificationMenuRef.current.contains(event.target)) {
        setNotificationsOpen(false);
      }
    };
    document.addEventListener('mousedown', handlePointerDown);
    return () => document.removeEventListener('mousedown', handlePointerDown);
  }, [notificationsOpen]);

  useEffect(() => {
    let cancelled = false;

    const syncWebPush = async () => {
      try {
        const result = await initializeFirebaseWebPush({
          onMessage: (payload) => {
            const row = {
              id: payload?.data?.notification_id || `push-${Date.now()}`,
              title: payload?.notification?.title || 'New notification',
              body: payload?.notification?.body || '',
              data: payload?.data || {},
              is_read: false,
              sent_at: new Date().toISOString(),
              created_at: new Date().toISOString(),
            };

            setNotificationItems((current) => {
              const exists = current.some((item) => String(item.id) === String(row.id));
              return exists ? current : [row, ...current].slice(0, 30);
            });
            setUnreadCount((count) => count + 1);
            knownNotificationIdsRef.current.add(row.id);
          },
        });

        if (cancelled || !result?.enabled || !result.token) return;

        await registerPushToken({
          token: result.token,
          platform: 'web',
          deviceId: result.deviceId,
        });

        setBrowserNotificationState('granted');
      } catch (_) {
        if (!cancelled && typeof window !== 'undefined' && 'Notification' in window) {
          setBrowserNotificationState(window.Notification.permission || 'default');
        }
      }
    };

    syncWebPush();

    return () => {
      cancelled = true;
    };
  }, [user?.id]);

  useEffect(() => {
    const playNotificationSound = () => {
      if (typeof window === 'undefined') return;
      const AudioContextImpl = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextImpl) return;
      if (!notificationAudioRef.current) {
        notificationAudioRef.current = new AudioContextImpl();
      }
      const ctx = notificationAudioRef.current;
      if (ctx.state === 'suspended') {
        ctx.resume().catch(() => {});
      }

      const oscillator = ctx.createOscillator();
      const gain = ctx.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(880, ctx.currentTime);
      gain.gain.setValueAtTime(0.0001, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.08, ctx.currentTime + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.22);
      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start();
      oscillator.stop(ctx.currentTime + 0.24);
    };

    const pushBrowserNotification = (row) => {
      if (typeof window === 'undefined' || !('Notification' in window)) return;
      if (window.Notification.permission !== 'granted') return;
      try {
        const notification = new window.Notification(row?.title || 'New notification', {
          body: row?.body || 'Open the dashboard to review the update.',
          tag: `agn-admin-${row?.id || 'notification'}`,
          silent: !notificationSoundEnabled,
        });
        notification.onclick = () => {
          window.focus();
          setNotificationsOpen(true);
          notification.close();
        };
      } catch (_) {
        // Browser notifications are best-effort only.
      }
    };

    const syncNotifications = (rows) => {
      const unreadRows = rows.filter((row) => !row?.is_read);
      const unreadIds = unreadRows.map((row) => row.id);
      const knownIds = knownNotificationIdsRef.current;
      const newUnreadRows = unreadRows.filter((row) => !knownIds.has(row.id));

      setNotificationItems(rows);
      setUnreadCount(unreadRows.length);

      if (unreadPrimedRef.current) {
        newUnreadRows.forEach(pushBrowserNotification);
      }

      knownNotificationIdsRef.current = new Set(unreadIds);
      lastUnreadRef.current = unreadRows.length;
      unreadPrimedRef.current = true;
    };

    const pollNotifications = async ({ allowSound }) => {
      if (notificationPollingRef.current) return;
      if (document.hidden) return;
      notificationPollingRef.current = true;
      try {
        const payload = await fetchNotifications({ page: 1, perPage: 30 });
        const rows = Array.isArray(payload?.data) ? payload.data : [];
        const unreadCount = rows.reduce((sum, row) => sum + (row?.is_read ? 0 : 1), 0);
        if (notificationSoundEnabled && unreadPrimedRef.current && allowSound && unreadCount > lastUnreadRef.current) {
          playNotificationSound();
        }
        syncNotifications(rows);
      } catch (_) {
        // Keep dashboard usable even if notification polling fails.
      } finally {
        notificationPollingRef.current = false;
      }
    };

    pollNotifications({ allowSound: false });
    notificationPollRef.current = setInterval(() => {
      pollNotifications({ allowSound: true });
    }, 20000);

    return () => {
      if (notificationPollRef.current) {
        clearInterval(notificationPollRef.current);
        notificationPollRef.current = null;
      }
      if (notificationAudioRef.current && typeof notificationAudioRef.current.close === 'function') {
        notificationAudioRef.current.close().catch(() => {});
      }
      notificationAudioRef.current = null;
      notificationPollingRef.current = false;
      setNotificationItems([]);
      setUnreadCount(0);
      knownNotificationIdsRef.current = new Set();
      unreadPrimedRef.current = false;
      lastUnreadRef.current = 0;
    };
  }, [user?.id, notificationSoundEnabled]);

  useEffect(() => {
    let timer = null;
    let cancelled = false;

    const pollSupportQueue = async () => {
      if (supportQueuePollingRef.current) return;
      supportQueuePollingRef.current = true;
      try {
        const payload = await fetchSupportQueue({ status: 'pending', page: 1, perPage: 1 });
        if (!cancelled) {
          setSupportQueueCount(Number(payload?.meta?.total || 0));
        }
      } catch (_) {
        if (!cancelled) {
          setSupportQueueCount(0);
        }
      } finally {
        supportQueuePollingRef.current = false;
      }
    };

    pollSupportQueue();
    timer = setInterval(pollSupportQueue, 20000);

    return () => {
      cancelled = true;
      if (timer) clearInterval(timer);
      supportQueuePollingRef.current = false;
      setSupportQueueCount(0);
    };
  }, [user?.id, isSuper]);

  const enableBrowserNotifications = async () => {
    const { config } = getFirebaseWebConfig();
    if (!config) {
      setBrowserNotificationState('missing-config');
      return;
    }
    if (typeof window === 'undefined' || !('Notification' in window)) {
      setBrowserNotificationState('unsupported');
      return;
    }
    try {
      const result = await enableFirebaseWebPush({
        onMessage: (payload) => {
          const row = {
            id: payload?.data?.notification_id || `push-${Date.now()}`,
            title: payload?.notification?.title || 'New notification',
            body: payload?.notification?.body || '',
            data: payload?.data || {},
            is_read: false,
            sent_at: new Date().toISOString(),
            created_at: new Date().toISOString(),
          };
          setNotificationItems((current) => {
            const exists = current.some((item) => String(item.id) === String(row.id));
            return exists ? current : [row, ...current].slice(0, 30);
          });
          setUnreadCount((count) => count + 1);
          knownNotificationIdsRef.current.add(row.id);
        },
      });
      await registerPushToken({
        token: result.token,
        platform: 'web',
        deviceId: result.deviceId,
      });
      setBrowserNotificationState('granted');
    } catch (_) {
      setBrowserNotificationState(window.Notification.permission || 'denied');
    }
  };

  const handleNotificationOpen = async (row) => {
    if (!row) return;
    if (!row.is_read) {
      setNotificationActionBusy(true);
      try {
        await markNotificationRead(row.id);
        setNotificationItems((current) => current.map((item) => (
          item.id === row.id ? { ...item, is_read: true, read_at: new Date().toISOString() } : item
        )));
        setUnreadCount((count) => Math.max(0, count - 1));
        knownNotificationIdsRef.current.delete(row.id);
        lastUnreadRef.current = Math.max(0, lastUnreadRef.current - 1);
      } catch (_) {
        // Keep panel responsive even if marking read fails.
      } finally {
        setNotificationActionBusy(false);
      }
    }

    const targetScreen = row?.data?.screen;
    if (targetScreen === 'institutions') {
      navigate(isSuper ? '/super/institutions' : '/institution/profile');
    } else if (targetScreen === 'users') {
      navigate(isSuper ? '/super/users' : '/institution/directory');
    } else if (targetScreen === 'support') {
      navigate(isSuper ? '/super/support' : '/institution/support');
    }

    setNotificationsOpen(false);
  };

  const handleMarkAllRead = async () => {
    setNotificationActionBusy(true);
    try {
      await markAllNotificationsRead();
      setNotificationItems((current) => current.map((item) => ({ ...item, is_read: true, read_at: item.read_at || new Date().toISOString() })));
      setUnreadCount(0);
      knownNotificationIdsRef.current = new Set();
      lastUnreadRef.current = 0;
    } finally {
      setNotificationActionBusy(false);
    }
  };

  const handleRefresh = () => {
    setRefreshing(true);
    window.location.reload();
  };

  const navItems = isSuper
      ? [
        { to: '/super/institutions', label: 'Institutions' },
        { to: '/super/users', label: 'Users' },
        { to: '/super/roles-permissions', label: 'Roles & Permissions' },
        { to: '/super/broadcasts', label: 'Broadcasts' },
        { to: '/super/jobs', label: 'Jobs' },
        { to: '/super/announcements', label: 'Announcements' },
        { to: '/super/payments', label: 'Payments' },
        { to: '/super/monetization', label: 'Monetization' },
        { to: '/super/subscriptions', label: 'Subscriptions' },
        { to: '/super/ads', label: 'Ads' },
        { to: '/super/directory', label: 'Directory' },
        { to: '/super/mentorship', label: 'Mentorship' },
        { to: '/super/analytics', label: 'Analytics' },
        { to: '/super/ai-controls', label: 'AI Controls' },
        { to: '/super/verification', label: 'Verification' },
        { to: '/super/reports', label: 'Reports' },
        { to: '/super/support', label: 'Support Queue' },
        { to: '/super/moderation/users', label: 'Moderation' },
        { to: '/super/audit-logs', label: 'Audit Logs' },
        { to: '/super/settings', label: 'Settings' },
        { to: '/super/institution-view/requests', label: 'Institution View' },
      ]
    : [
        { to: '/institution/dashboard', label: 'Dashboard' },
        { to: '/institution/profile', label: 'Institution Profile' },
        { to: '/institution/payment-settings', label: 'Payment Settings' },
        { to: '/institution/requests', label: 'Join Requests' },
        { to: '/institution/jobs', label: 'Jobs' },
        { to: '/institution/announcements', label: 'Announcements' },
        { to: '/institution/payments', label: 'Payments' },
        { to: '/institution/subscriptions', label: 'Subscriptions' },
        { to: '/institution/ads', label: 'Ads' },
        { to: '/institution/directory', label: 'Directory' },
        { to: '/institution/mentorship', label: 'Mentorship' },
        { to: '/institution/events', label: 'Events' },
        { to: '/institution/donations', label: 'Donations' },
        { to: '/institution/analytics', label: 'Analytics' },
        { to: '/institution/verification', label: 'Verification' },
        { to: '/institution/support', label: 'Support Queue' },
        { to: '/institution/moderation/users', label: 'Moderation' },
        { to: '/institution/audit-logs', label: 'Audit Logs' },
      ];

  const quickActions = isSuper
    ? [
        { label: 'Users', to: '/super/users' },
        { label: 'Payments', to: '/super/payments' },
        { label: 'Support', to: '/super/support' },
        { label: 'Settings', to: '/super/settings' },
      ]
    : [
        { label: 'Profile', to: '/institution/profile' },
        { label: 'Payments', to: '/institution/payments' },
        { label: 'Support', to: '/institution/support' },
        { label: 'Analytics', to: '/institution/analytics' },
      ];

  const unreadNotifications = notificationItems.filter((row) => !row?.is_read);
  const recentNotifications = notificationItems.filter((row) => row?.is_read);

  return (
    <div className={`shell ${isSuper ? 'shell--super' : ''}${mobileNavOpen ? ' shell--nav-open' : ''}`}>
      {mobileNavOpen && <div className="mobile-overlay" onClick={() => setMobileNavOpen(false)} />}
      <aside className="sidebar">
        <div className="specialist-sidebar-head">
          <div className="specialist-sidebar-brand">
            <span className="specialist-sidebar-mark">AG</span>
            <div className="specialist-sidebar-copy">
              <strong>Alumni Global Network</strong>
              <span>{isSuper ? 'Super admin portal' : 'Institution admin portal'}</span>
            </div>
          </div>
          <div className="specialist-sidebar-user">
            <span className="specialist-sidebar-user__avatar">
              {(user?.name || 'A').trim().charAt(0).toUpperCase()}
            </span>
            <div className="specialist-sidebar-copy">
              <strong>{user?.name || 'Admin user'}</strong>
              <span>{isSuper ? 'Platform access' : (user?.institution?.name || 'Institution access')}</span>
            </div>
          </div>
        </div>
        <nav className="nav">
      {navItems.map((item) => {
        const isSupportItem = item.to === '/super/support' || item.to === '/institution/support';
        const badgeCount = isSupportItem ? supportQueueCount : 0;
        return (
        <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `nav-item${isActive ? ' nav-item--active' : ''}`}
              onClick={() => setMobileNavOpen(false)}
            >
              <span className="nav-item__main">
                <PortalGlyph
                  type={
                    item.label.includes('Institution') ? 'dashboard'
                    : item.label === 'Users' ? 'profile'
                    : item.label.includes('Roles') ? 'reports'
                    : item.label === 'Broadcasts' ? 'reports'
                    : item.label === 'Jobs' ? 'transactions'
                    : item.label === 'Announcements' ? 'reports'
                    : item.label === 'Payments' ? 'transactions'
                    : item.label === 'Monetization' ? 'receipts'
                    : item.label === 'Subscriptions' ? 'subscriptions'
                    : item.label === 'Ads' ? 'dashboard'
                    : item.label === 'Directory' ? 'profile'
                    : item.label === 'Mentorship' ? 'profile'
                    : item.label === 'Analytics' ? 'reports'
                    : item.label === 'AI Controls' ? 'dashboard'
                    : item.label === 'Verification' ? 'billing'
                    : item.label === 'Reports' ? 'reports'
                    : item.label.includes('Support') ? 'billing'
                    : item.label === 'Moderation' ? 'failed'
                    : item.label === 'Audit Logs' ? 'receipts'
                    : item.label === 'Settings' ? 'profile'
                    : item.label === 'Institution Profile' ? 'profile'
                    : item.label === 'Payment Settings' ? 'transactions'
                    : item.label === 'Join Requests' ? 'billing'
                    : item.label === 'Events' ? 'dashboard'
                    : item.label === 'Donations' ? 'receipts'
                    : 'dashboard'
                  }
                />
                <span>{item.label}</span>
              </span>
              {badgeCount > 0 ? <span className="nav-badge">{badgeCount > 99 ? '99+' : badgeCount}</span> : null}
            </NavLink>
          );
        })}
        </nav>
      </aside>
      <main className="content">
        <div className="topbar">
          <div className="topbar-heading">
            <button
              className="ghost mobile-nav-toggle"
              onClick={() => setMobileNavOpen((prev) => !prev)}
              aria-label="Toggle navigation"
              type="button"
            >
              <span className="hamburger">
                <span />
                <span />
                <span />
              </span>
            </button>
            <div className="topbar-title">{isSuper ? 'Super Admin' : 'Institution Admin'}</div>
            <div className="topbar-subtitle">
              {isSuper
                ? 'Platform command center'
                : `Institution command center • ${user?.institution?.name || 'Unassigned'}`}
            </div>
          </div>
          <div className="topbar-actions">
            <div className="topbar-brand">Alumni Global Network</div>
            {isSuper && (
              <div className="view-as">
                <span>View as:</span>
                <select
                  className="select"
                  value={viewAsInstitutionId || ''}
                  onChange={(e) => {
                    const value = e.target.value ? Number(e.target.value) : null;
                    onViewAsChange(value);
                    if (value) {
                      navigate('/super/institution-view/requests');
                    }
                  }}
                >
                  <option value="">Select institution</option>
                  {institutions.map((inst) => (
                    <option key={inst.id} value={inst.id}>{inst.name}</option>
                  ))}
                </select>
                {viewAsInstitutionId && (
                  <button
                    className="ghost"
                    onClick={() => {
                      onViewAsChange(null);
                      navigate('/super/institutions');
                    }}
                  >
                    Clear
                  </button>
                )}
              </div>
            )}
            <div className="topbar-chip">
              Connected · {lastRefresh.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </div>
            <button
              className="ghost topbar-icon-button"
              type="button"
              onClick={handleRefresh}
              disabled={refreshing}
              title={refreshing ? 'Refreshing portal' : 'Refresh portal'}
            >
              <PortalGlyph type="refresh" />
            </button>
            <div className="notification-menu" ref={notificationMenuRef}>
              <button
                className={`ghost notification-toggle ${notificationsOpen ? 'notification-toggle--active' : ''}`}
                type="button"
                onClick={() => setNotificationsOpen((prev) => !prev)}
                title="Notifications"
              >
                <BellIcon />
                {unreadCount > 0 && <span className="notification-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>}
              </button>
              {notificationsOpen && (
                <div className="notification-panel">
                  <div className="notification-panel__header">
                    <div>
                      <strong>Notifications</strong>
                      <small>{unreadCount > 0 ? `${unreadCount} unread` : 'All caught up'}</small>
                    </div>
                    <button className="ghost" type="button" onClick={handleMarkAllRead} disabled={notificationActionBusy || unreadCount === 0}>
                      Mark all read
                    </button>
                  </div>
                  {browserNotificationState !== 'granted' && (
                    <div className="notification-panel__permission">
                      <span>
                        {browserNotificationState === 'missing-config'
                          ? 'Firebase web push config is missing for this build.'
                          : browserNotificationState === 'unsupported'
                          ? 'Browser alerts are not supported here.'
                          : 'Enable browser alerts for real-time popups.'}
                      </span>
                      {browserNotificationState !== 'unsupported' && browserNotificationState !== 'missing-config' && (
                        <button className="ghost" type="button" onClick={enableBrowserNotifications}>
                          {browserNotificationState === 'denied' ? 'Retry permission' : 'Enable alerts'}
                        </button>
                      )}
                    </div>
                  )}
                  <div className="notification-panel__list">
                    {notificationItems.length === 0 ? (
                      <div className="notification-empty">No notifications yet.</div>
                    ) : (
                      <>
                        {unreadNotifications.length > 0 && (
                          <div className="notification-group">
                            <div className="notification-group__label">Unread</div>
                            {unreadNotifications.map((row) => {
                              const priority = (row?.data?.priority || '').toString().toLowerCase();
                              const isSupportTicket = row?.data?.screen === 'support' || row?.data?.ticket_id;
                              const showPriority = isSupportTicket && ['low', 'normal', 'high', 'urgent'].includes(priority);
                              return (
                                <button
                                  key={row.id}
                                  type="button"
                                  className="notification-row notification-row--unread"
                                  onClick={() => handleNotificationOpen(row)}
                                  disabled={notificationActionBusy}
                                >
                                  <div className="notification-row__meta">
                                    <div className="notification-row__title-wrap">
                                      <strong>{row.title}</strong>
                                      {showPriority ? (
                                        <span className={`notification-priority notification-priority--${priority}`}>
                                          {priority}
                                        </span>
                                      ) : null}
                                    </div>
                                    <span>{formatNotificationTime(row.sent_at || row.created_at)}</span>
                                  </div>
                                  {row.body ? <div className="notification-row__body">{row.body}</div> : null}
                                </button>
                              );
                            })}
                          </div>
                        )}
                        {recentNotifications.length > 0 && (
                          <div className="notification-group">
                            <div className="notification-group__label">Recent</div>
                            {recentNotifications.map((row) => {
                              const priority = (row?.data?.priority || '').toString().toLowerCase();
                              const isSupportTicket = row?.data?.screen === 'support' || row?.data?.ticket_id;
                              const showPriority = isSupportTicket && ['low', 'normal', 'high', 'urgent'].includes(priority);
                              return (
                                <button
                                  key={row.id}
                                  type="button"
                                  className="notification-row"
                                  onClick={() => handleNotificationOpen(row)}
                                  disabled={notificationActionBusy}
                                >
                                  <div className="notification-row__meta">
                                    <div className="notification-row__title-wrap">
                                      <strong>{row.title}</strong>
                                      {showPriority ? (
                                        <span className={`notification-priority notification-priority--${priority}`}>
                                          {priority}
                                        </span>
                                      ) : null}
                                    </div>
                                    <span>{formatNotificationTime(row.sent_at || row.created_at)}</span>
                                  </div>
                                  {row.body ? <div className="notification-row__body">{row.body}</div> : null}
                                </button>
                              );
                            })}
                          </div>
                        )}
                      </>
                    )}
                  </div>
                </div>
              )}
            </div>
            <button
              className={`ghost sound-toggle ${notificationSoundEnabled ? 'sound-toggle--on' : 'sound-toggle--off'}`}
              type="button"
              onClick={() => setNotificationSoundEnabled((prev) => !prev)}
              title="Toggle notification sound"
            >
              <SoundIcon enabled={notificationSoundEnabled} />
              Sound {notificationSoundEnabled ? 'On' : 'Off'}
            </button>
            <button className="ghost topbar-icon-button topbar-icon-button--danger" type="button" onClick={onLogout} title="Log out">
              <PortalGlyph type="logout" />
            </button>
          </div>
        </div>
        <div className="command-bar">
          {quickActions.map((action) => (
            <button
              key={action.to}
              type="button"
              className="ghost command-chip"
              onClick={() => navigate(action.to)}
            >
              {action.label}
            </button>
          ))}
        </div>
        <Routes>
          <Route
            path="/super/institutions"
            element={isSuper ? <SuperInstitutionsPage /> : <Navigate to="/institution/requests" replace />}
          />
          <Route path="/super/users" element={isSuper ? <UsersView allowHardDelete institutions={institutions} roleCatalog={roleCatalog} /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/roles-permissions" element={isSuper ? <RolesPermissionsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/jobs" element={isSuper ? <JobsView institutions={institutions} /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/announcements" element={isSuper ? <AnnouncementsView institutions={institutions} /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/payments" element={isSuper ? <TransactionsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/subscriptions" element={isSuper ? <SubscriptionsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/ads" element={isSuper ? <AdsView institutions={institutions} isSuper /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/broadcasts" element={isSuper ? <BroadcastNotificationsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/directory" element={isSuper ? <DirectorySearchView institutions={institutions} isSuper /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/mentorship" element={isSuper ? <MentorshipView institutions={institutions} isSuper /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/analytics" element={isSuper ? <SuperAnalyticsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/ai-controls" element={isSuper ? <AiControlsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/verification" element={isSuper ? <VerificationView institutionId={viewAsInstitutionId} scopeLabel={viewAsInstitutionId ? institutions.find((i) => i.id === viewAsInstitutionId)?.name : null} /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/reports" element={isSuper ? <ReportsView institutions={institutions} isSuper /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/support" element={isSuper ? <SupportQueueView onPendingCountChange={setSupportQueueCount} /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/moderation/users" element={isSuper ? <ModerationView mode="users" basePath="/super/moderation" /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/moderation/posts" element={isSuper ? <ModerationView mode="posts" basePath="/super/moderation" /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/audit-logs" element={isSuper ? <AuditLogsView currentUser={user} /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/settings" element={isSuper ? <SettingsView /> : <Navigate to="/institution/requests" replace />} />
          <Route path="/super/monetization" element={isSuper ? <MonetizationView /> : <Navigate to="/institution/requests" replace />} />

          <Route
            path="/super/institution-view/*"
            element={isSuper ? (
              <div className="stack">
                <InstitutionViewNav />
                <Routes>
                  <Route
                    path="dashboard"
                    element={
                      <InstitutionDashboardView
                        institutionId={viewAsInstitutionId}
                        scopeLabel={viewAsInstitutionId ? institutions.find((i) => i.id === viewAsInstitutionId)?.name : null}
                        basePath="/super/institution-view"
                      />
                    }
                  />
                  <Route path="requests" element={<InstitutionRequestsView institutionId={viewAsInstitutionId} />} />
                  <Route path="jobs" element={<JobsView institutionId={viewAsInstitutionId} institutions={institutions} scopeLabel={viewAsInstitutionId ? institutions.find((i) => i.id === viewAsInstitutionId)?.name : null} />} />
                  <Route path="events" element={<EventsPage institutionId={viewAsInstitutionId} allowHardDelete currentUser={user} />} />
                  <Route path="donations" element={<DonationsPage institutionId={viewAsInstitutionId} allowHardDelete />} />
                  <Route path="payment-settings" element={<PaymentSettingsView institutionId={viewAsInstitutionId} isSuper scopeLabel={viewAsInstitutionId ? institutions.find((i) => i.id === viewAsInstitutionId)?.name : null} />} />
                  <Route path="analytics" element={<InstitutionAnalyticsView institutionId={viewAsInstitutionId} />} />
                  <Route path="*" element={<Navigate to="dashboard" replace />} />
                </Routes>
              </div>
            ) : (
              <Navigate to="/institution/requests" replace />
            )}
          />

          <Route
            path="/institution/dashboard"
            element={!isSuper ? <InstitutionDashboardView institutionId={user?.institution?.id} scopeLabel={user?.institution?.name} basePath="/institution" /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/profile"
            element={!isSuper ? <InstitutionProfileView institutionId={user?.institution?.id} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/payment-settings"
            element={!isSuper ? <PaymentSettingsView institutionId={user?.institution?.id} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/requests"
            element={!isSuper ? <InstitutionRequestsView institutionId={user?.institution?.id} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/jobs"
            element={!isSuper ? <JobsView institutionId={user?.institution?.id} scopeLabel={user?.institution?.name} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/announcements"
            element={!isSuper ? <AnnouncementsView institutionId={user?.institution?.id} scopeLabel={user?.institution?.name} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/payments"
            element={!isSuper ? <TransactionsView institutionId={user?.institution?.id} scopeLabel={user?.institution?.name} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/subscriptions"
            element={!isSuper ? <SubscriptionsView institutionId={user?.institution?.id} scopeLabel={user?.institution?.name} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/ads"
            element={!isSuper ? <AdsView scopeLabel={user?.institution?.name} institutions={institutions} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/directory"
            element={!isSuper ? <DirectorySearchView institutions={institutions} isSuper={false} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/mentorship"
            element={!isSuper ? <MentorshipView institutionId={user?.institution?.id} institutions={institutions} scopeLabel={user?.institution?.name} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/events"
            element={!isSuper ? <EventsPage institutionId={user?.institution?.id} currentUser={user} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/donations"
            element={!isSuper ? <DonationsPage institutionId={user?.institution?.id} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/analytics"
            element={!isSuper ? <InstitutionAnalyticsView institutionId={user?.institution?.id} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/verification"
            element={!isSuper ? <VerificationView institutionId={user?.institution?.id} scopeLabel={user?.institution?.name} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/support"
            element={!isSuper ? <SupportQueueView scopeLabel={user?.institution?.name} onPendingCountChange={setSupportQueueCount} /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/moderation/users"
            element={!isSuper ? <ModerationView mode="users" basePath="/institution/moderation" /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/moderation/posts"
            element={!isSuper ? <ModerationView mode="posts" basePath="/institution/moderation" /> : <Navigate to="/super/institutions" replace />}
          />
          <Route
            path="/institution/audit-logs"
            element={!isSuper ? <AuditLogsView currentUser={user} /> : <Navigate to="/super/institutions" replace />}
          />

          <Route
            path="*"
            element={
              isSuper ? <Navigate to="/super/institutions" replace /> : <Navigate to="/institution/dashboard" replace />
            }
          />
        </Routes>
        <footer className="powered-by powered-by--content">Powered by Verix Teams</footer>
      </main>
    </div>
  );
}

export default function App() {
  const [token, setTokenState] = useState(getToken());
  const [user, setUserState] = useState(getUser());
  const [institutions, setInstitutions] = useState([]);
  const [viewAsInstitutionId, setViewAsInstitutionId] = useState(null);
  const [roleCatalog, setRoleCatalog] = useState(BUILTIN_ROLE_CATALOG);
  const navigate = useNavigate();
  const location = useLocation();
  const idleTimerRef = useRef(null);
  const portal = inferPortalFromPath(location.pathname);

  useEffect(() => {
    if (!token) return;
    const idleMs = 10 * 60 * 1000;
    const resetTimer = () => {
      if (idleTimerRef.current) {
        clearTimeout(idleTimerRef.current);
      }
      idleTimerRef.current = setTimeout(() => {
        handleLogout();
      }, idleMs);
    };

    const events = ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart'];
    events.forEach((evt) => window.addEventListener(evt, resetTimer, { passive: true }));
    resetTimer();

    return () => {
      if (idleTimerRef.current) {
        clearTimeout(idleTimerRef.current);
      }
      events.forEach((evt) => window.removeEventListener(evt, resetTimer));
    };
  }, [token]);

  useEffect(() => {
    if (!token || !user || user.role !== 'super_admin') return;
    fetchInstitutions({ status: 'active', page: 1, perPage: 200 })
      .then((data) => {
        const list = data?.data || [];
        setInstitutions(list);
      })
      .catch(() => {});
  }, [token, user]);

  useEffect(() => {
    if (!token) {
      setRoleCatalog(BUILTIN_ROLE_CATALOG);
      return;
    }

    fetchRoleConfig()
      .then((res) => {
        setRoleCatalog(getRoleCatalog(res?.data?.roles));
      })
      .catch(() => {
        setRoleCatalog(BUILTIN_ROLE_CATALOG);
      });
  }, [token]);

  function handleLogin(nextToken, nextUser) {
    setToken(nextToken);
    setUser(nextUser);
    setTokenState(nextToken);
    setUserState(nextUser);
    const target = roleHomePath(nextUser?.role, roleCatalog);
    navigate(
      target !== '/'
        ? target
        : portal === 'accounting'
          ? '/accounting/dashboard'
          : portal === 'support'
            ? '/customer-support/dashboard'
            : '/super/institutions',
      { replace: true }
    );
  }

  async function handleLogout() {
    try {
      const { token: pushToken } = await disableFirebaseWebPush();
      if (pushToken) {
        await unregisterPushToken(pushToken);
      }
    } catch (_) {
      // Logout should complete even if web push cleanup fails.
    }
    setToken('');
    setUser(null);
    setTokenState('');
    setUserState(null);
    setInstitutions([]);
    setViewAsInstitutionId(null);
    navigate(
      portal === 'accounting'
        ? '/accounting/login'
        : portal === 'support'
          ? '/customer-support/login'
          : '/',
      { replace: true }
    );
  }

  if (!token) {
    return <LoginPanel onLogin={handleLogin} portal={portal} />;
  }

  const knownRole =
    !!user &&
    (user.role === 'super_admin' ||
      user.role === 'institution_admin' ||
      Object.prototype.hasOwnProperty.call(roleCatalog || {}, user.role));

  if (!user || !knownRole) {
    return (
      <div className="auth-shell">
        <div className="auth-card">
          <div className="auth-title">Access denied</div>
          <p className="auth-subtitle">Your account does not have dashboard access.</p>
          <button className="ghost" onClick={handleLogout}>Log out</button>
          <div className="powered-by">Powered by Verix Teams</div>
        </div>
      </div>
    );
  }

  if (!portalAllowsRole(portal, user.role, roleCatalog)) {
    return <Navigate to={roleHomePath(user.role, roleCatalog)} replace />;
  }

  if (roleCatalog?.[user.role]?.portal === 'accounting') {
    return <AccountingPortal user={user} onLogout={handleLogout} />;
  }

  if (roleCatalog?.[user.role]?.portal === 'support') {
    return <SupportPortal user={user} onLogout={handleLogout} roleCatalog={roleCatalog} />;
  }

  return (
    <AdminLayout
      user={user}
      onLogout={handleLogout}
      institutions={institutions}
      viewAsInstitutionId={viewAsInstitutionId}
      onViewAsChange={setViewAsInstitutionId}
      roleCatalog={roleCatalog}
    />
  );
}
