# Alumni Global API Contract (v1)

Base URL: `/api`

Auth: Bearer token via Laravel Sanctum (`Authorization: Bearer <token>`)

## Standard Response Shapes

### 1) Standard success
```json
{
  "message": "Optional message",
  "data": {}
}
```

### 2) Paginated list (standardized)
```json
{
  "data": [],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 120,
    "last_page": 6
  }
}
```

### 3) Validation error
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "field": ["..."]
  }
}
```

### 4) Authorization error
```json
{ "message": "Not authorized" }
```

---

## Auth & Account

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`
- `POST /auth/forgot-password`
- `POST /auth/reset-password`
- `POST /auth/social/google`
- `POST /auth/social/apple`
- `POST /email/verification-notification`
- `GET /email/verify/{id}/{hash}`
- `POST /users/{user}/suspend`
- `POST /users/{user}/reactivate`

### Register (example)
`POST /auth/register`
```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "password": "Password123!",
  "password_confirmation": "Password123!",
  "user_type": "alumni"
}
```
Response:
```json
{
  "token": "...",
  "user": {
    "id": 1,
    "name": "Jane Doe",
    "email": "jane@example.com",
    "role": "alumni",
    "status": "active",
    "institution": null,
    "profile": null
  }
}
```

---

## Me / Profile

- `GET /me`
- `PATCH /me`
- `POST /me/attach-institution`
- `GET /profiles/me`
- `PATCH /profiles/me`
- `GET /profiles/{user}`
- `PATCH /profiles/{user}`
- `POST /profiles/{user}/request-verification`
- `POST /profiles/{user}/verify`
- `POST /profiles/{user}/reject`

`GET /me` response:
```json
{
  "user": {
    "id": 1,
    "name": "Jane Doe",
    "email": "jane@example.com",
    "role": "alumni",
    "status": "active",
    "institution": { "id": 10, "name": "Uni", "slug": "uni", "status": "active" },
    "profile": {
      "headline": "Software Engineer",
      "bio": "...",
      "skills": ["Flutter", "Laravel"],
      "visibility": "public",
      "verification_status": "verified"
    }
  },
  "profile": {
    "headline": "Software Engineer",
    "bio": "...",
    "skills": ["Flutter", "Laravel"],
    "visibility": "public",
    "verification_status": "verified"
  }
}
```

---

## Institutions, Directory, Feed

### Institutions
- `GET /institutions`
- `POST /institutions/register`
- `POST /institutions/{institution}/join-request`
- `GET /institutions/{institution}/join-requests`
- `POST /institutions/{institution}/join-requests/{membership}/approve`
- `POST /institutions/{institution}/join-requests/{membership}/reject`
- `GET /institutions/{institution}/feed`
- `GET /institutions/{institution}/analytics`

### Directory
- `GET /directory`

Supported query filters:
- `q`
- `institution_id`
- `graduation_year`
- `program`
- `department`
- `location`
- `skills[]`
- `verified_only`
- `visibility`
- `sort` (`recent|az`)
- `per_page`, `page`

### Feed
- `GET /feed/global?sort=chrono|relevance|ai`
- `GET /feed/institutions/{institutionId}?sort=chrono|relevance|ai`

Feed response:
```json
{
  "sort": "ai",
  "announcements": {
    "data": [],
    "meta": { "total": 1 }
  },
  "posts": {
    "data": [],
    "meta": { "page": 1, "per_page": 20, "total": 45, "last_page": 3 }
  }
}
```

### Announcements
- `POST /announcements`

Request:
```json
{
  "title": "Global update",
  "body": "Maintenance notice",
  "audience": "global"
}
```

---

## Content & Stories

### Posts
- `GET /posts`
- `POST /posts`
- `GET /posts/{post}`
- `DELETE /posts/{post}`
- `POST /posts/{post}/comments`
- `GET /posts/{post}/comments`
- `POST /posts/{post}/like`
- `DELETE /posts/{post}/like`
- `POST /posts/{post}/report`
- `POST /posts/{post}/pin`
- `POST /posts/{post}/unpin`

Create post request:
```json
{
  "content": "Hello alumni",
  "visibility": "public",
  "media": [{ "type": "image", "url": "https://..." }]
}
```

### Stories
- `GET /stories`
- `POST /stories`
- `POST /stories/{story}/view`
- `GET /stories/{story}/views`
- `DELETE /stories/{story}`

Create story request:
```json
{
  "caption": "Campus update",
  "visibility": "institution_only",
  "media": [{ "type": "image", "url": "https://..." }]
}
```

---

## Jobs

- `GET /jobs`

Query params:
- `q`
- `category`
- `per_page`, `page`

---

## Events

- `GET /events`
- `POST /events`
- `GET /events/{event}`
- `POST /events/{event}/rsvp`

Create event request:
```json
{
  "title": "Alumni Meetup",
  "event_type": "physical",
  "starts_at": "2026-03-01T10:00:00Z",
  "capacity": 100,
  "is_paid": true,
  "price": 20,
  "currency": "USD",
  "payment_provider": "stripe"
}
```

RSVP request:
```json
{
  "status": "going",
  "reminder_enabled": true
}
```

---

## Messaging, Networking, Safety, Moderation

### Connections
- `GET /connections`
- `POST /connections/{user}`
- `POST /connections/{connection}/respond`

### Messages
- `GET /messages/{user}`
- `POST /messages/{user}`

Send message request:
```json
{ "body": "Hi, let's connect!" }
```

### User safety
- `POST /users/{user}/block`
- `DELETE /users/{user}/block`
- `POST /users/{user}/report`

### Moderation
- `GET /moderation/user-reports`
- `POST /moderation/user-reports/{report}/resolve`

Resolve report request:
```json
{ "status": "resolved" }
```

---

## Student ID

- `POST /student-ids/generate`
- `POST /student-ids/request`

Generate request:
```json
{ "institution_id": 10 }
```

Request ID:
```json
{
  "institution_id": 10,
  "full_name": "Jane Doe",
  "email": "jane@example.com"
}
```

---

## Notifications

- `GET /notifications`
- `POST /notifications/{notification}/read`
- `POST /notifications/read-all`
- `GET /notification-preferences`
- `PATCH /notification-preferences`
- `POST /notifications/push-token`
- `DELETE /notifications/push-token`

Preferences request:
```json
{
  "in_app_enabled": true,
  "push_enabled": true,
  "email_enabled": false,
  "messages_enabled": true,
  "connections_enabled": true,
  "events_enabled": true
}
```

---

## Payments, Donations, Subscriptions

### Payments
- `POST /payments/initiate`
- `GET /payments/history`
- `POST /payments/{transaction}/refund`
- `GET /admin/payments/transactions`

Initiate payment request:
```json
{
  "type": "membership_fee",
  "provider": "stripe",
  "amount": 50,
  "currency": "USD"
}
```

Refund request:
```json
{ "reason": "duplicate" }
```

### Subscriptions
- `POST /subscriptions`
- `GET /admin/subscriptions`
- `POST /admin/subscriptions/{subscription}/cancel`

Request:
```json
{
  "plan_name": "Premium Alumni",
  "interval": "monthly",
  "amount": 9.99,
  "currency": "USD",
  "provider": "flutterwave"
}
```

### Donation campaigns
- `GET /donation-campaigns`
- `POST /donation-campaigns`
- `GET /donation-campaigns/{campaign}`
- `POST /donation-campaigns/{campaign}/donate`
- `GET /donation-campaigns/{campaign}/report`

Donate request:
```json
{
  "provider": "paystack",
  "amount": 100,
  "currency": "USD",
  "is_anonymous": false,
  "message": "Proud alum!"
}
```

---

## Ads & Monetization

- `GET /ads`
- `POST /ads`
- `PATCH /ads/{ad}`
- `DELETE /ads/{ad}`
- `POST /ads/serve`
- `POST /ads/{ad}/click`
- `GET /ads/{ad}/analytics`

Create ad request:
```json
{
  "title": "Sponsored Career Fair",
  "placement": "feed",
  "pricing_model": "cpc",
  "price": 1.5,
  "budget": 100,
  "currency": "USD",
  "target_institution_id": 10,
  "target_interests": ["tech", "jobs"]
}
```

Serve ad request:
```json
{
  "placement": "feed",
  "institution_id": 10,
  "location": "Lagos",
  "interests": ["tech"]
}
```

---

## AI Recommendations & Intelligence

- `GET /recommendations?type=content|event|connection`
- `POST /recommendations/{recommendation}/feedback`
- `GET /ai/controls`
- `PATCH /ai/controls`
- `GET /ai/performance`

Feedback request:
```json
{ "action": "clicked" }
```

AI controls request (super admin):
```json
{
  "feed_personalization_enabled": true,
  "recommendations_enabled": true,
  "max_daily_recommendations": 250,
  "guardrails": { "nsfw": true }
}
```

---

## Admin Support & Settings

- `GET /admin/support/queue`
- `GET /admin/audit-logs`
- `GET /admin/settings`
- `PATCH /admin/settings`

System settings update request:
```json
{
  "settings": {
    "maintenance_banner": "Scheduled maintenance at 2AM",
    "feature_flags": ["ads", "ai_feed"],
    "data_retention_days": 365,
    "default_moderation_rules": ["no hate speech", "no harassment"]
  }
}
```

---

## Analytics & Dashboards

### Analytics
- `POST /analytics/track`
- `GET /analytics/institutions/{institution}`
- `GET /analytics/platform`
- `GET /analytics/content-performance`
- `GET /analytics/user`

Track analytics request:
```json
{
  "event_type": "post_view",
  "entity_type": "post",
  "entity_id": 123,
  "value": 1,
  "metadata": { "source": "feed" }
}
```

### Dashboards
- `GET /dashboard/institution` (institution admin)
- `GET /dashboard/super` (super admin)

---

## Role Access (Summary)

- `alumni`: profile/content/events/networking/payments, personal notifications/preferences.
- `institution_admin`: moderation in institution, institution campaigns/events/analytics/dashboard.
- `super_admin`: platform-wide analytics, AI controls, broad moderation, global announcements.

### Admin Permissions (Detailed)

**Institution Admin**
- Can view: `/dashboard/institution`, `/analytics/institutions/{institution}`
- Can manage: `/institutions/{institution}/join-requests/*`, `/institutions/{institution}/feed`, `/events`, `/donation-campaigns`, `/posts`, `/stories`, `/announcements`
- Can moderate: `/moderation/user-reports` (institution scope), `/users/{user}/report`

**Super Admin**
- Can view: `/dashboard/super`, `/analytics/platform`, `/analytics/content-performance`
- Can manage: `/admin/institutions`, `/admin/institutions/{institution}/status`
- Can moderate: `/users/{user}/suspend`, `/users/{user}/reactivate`, `/moderation/user-reports`
- Can control: `/ai/controls`, `/ai/performance`

---

## Notes For Flutter Team

1. Prefer using `meta.total` and `meta.last_page` for infinite scroll termination.
2. Most list endpoints now return standardized `data + meta`.
3. Feed/Connections are nested lists (`announcements`, `posts`, `sent`, `received`) each with their own list envelope.
4. `currency` is always 3-letter ISO format (e.g., `USD`, `NGN`, `GBP`).
5. Payments and provider flows are currently mocked at API level for integration scaffolding.


### Admin (Super Admin)
- `GET /admin/institutions` (super admin)
  - Query: `status`, `search`, `page`, `per_page`
- `PATCH /admin/institutions/{institution}/status` (super admin)
  - Body: `{ "status": "pending|active|rejected|suspended" }`

### Public Institutions (Registration)
- `GET /institutions/public` (no auth)
  - Query: `search`

### Registration Validation
- `POST /auth/register`
  - If alumni must pick an institution, error response includes:
    - `requires_institution: true`
    - `errors.institution_id`

### Admin (Super Admin) - Create Institution
- `POST /admin/institutions`
  - Body: `{ "name": "School Name", "status": "pending|active|rejected|suspended" }`

### Admin (Super Admin) - Users
- `GET /admin/users`
  - Query: `search`, `role`, `status`, `institution_id`, `page`, `per_page`

### Admin - Events (Edit/Deactivate)
- `PATCH /events/{event}`
- `DELETE /events/{event}` (deactivate)

### Admin - Donation Campaigns (Edit/Deactivate)
- `PATCH /donation-campaigns/{campaign}`
- `DELETE /donation-campaigns/{campaign}` (deactivate)

### Moderation
- `GET /moderation/user-reports` (institution admin + super admin)
- `POST /moderation/user-reports/{report}/resolve`

### Admin - Hard Delete (Super Admin)
- `DELETE /admin/events/{event}/purge`
- `DELETE /admin/donation-campaigns/{campaign}/purge`

### Moderation - Post Reports
- `GET /moderation/post-reports`
- `POST /moderation/post-reports/{report}/resolve`

### Admin - Hard Delete Users (Super Admin)
- `DELETE /admin/users/{user}/purge`
