<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DirectoryController;
use App\Http\Controllers\Api\EventController;
use App\Http\Controllers\Api\FeedController;
use App\Http\Controllers\Api\InstitutionController;
use App\Http\Controllers\Api\InstitutionMembershipController;
use App\Http\Controllers\Api\InstitutionYearGroupController;
use App\Http\Controllers\Api\InvitationController;
use App\Http\Controllers\Api\AnnouncementController;
use App\Http\Controllers\Api\ConnectionController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DonationCampaignController;
use App\Http\Controllers\Api\GroupChatController;
use App\Http\Controllers\Api\JobController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\MediaUploadController;
use App\Http\Controllers\Api\ModerationController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\NotificationPreferenceController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PostController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\RecommendationController;
use App\Http\Controllers\Api\SocialAuthController;
use App\Http\Controllers\Api\StoryController;
use App\Http\Controllers\Api\UserSafetyController;
use App\Http\Controllers\Api\UserAdminController;
use App\Http\Controllers\Api\VerificationController;
use App\Http\Controllers\Api\PushTokenController;
use App\Http\Controllers\Api\StudentIdController;
use App\Http\Controllers\Api\AdController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\AdminPaymentController;
use App\Http\Controllers\Api\AdminInstitutionController;
use App\Http\Controllers\Api\AdminNotificationBroadcastController;
use App\Http\Controllers\Api\AdminUserController;
use App\Http\Controllers\Api\AuditLogController;
use App\Http\Controllers\Api\SupportController;
use App\Http\Controllers\Api\SystemSettingController;
use App\Http\Controllers\Api\TypingController;
use App\Http\Controllers\Api\SupportTicketController;
use App\Http\Controllers\Api\CallController;
use App\Http\Controllers\Api\ChatPreferenceController;
use App\Http\Controllers\Api\InstitutionPaymentSettingController;
use App\Http\Controllers\Api\InstitutionEmailSettingController;
use App\Http\Controllers\Api\PlatformPaymentSettingController;
use App\Http\Controllers\Api\NewsletterController;
use App\Http\Controllers\Api\PaymentWebhookController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/invitations/validate', [InvitationController::class, 'validateCode']);

Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:auth');
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:auth');
Route::post('/auth/resend-verification', [AuthController::class, 'resendVerification'])->middleware('throttle:auth');
Route::post('/auth/social/google', [SocialAuthController::class, 'google'])->middleware('throttle:auth');
Route::post('/auth/social/apple', [SocialAuthController::class, 'apple'])->middleware('throttle:auth');
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:auth');
Route::post('/auth/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:auth');
Route::post('/newsletter/subscribe', [NewsletterController::class, 'subscribe']);
Route::get('/newsletter/unsubscribe', [NewsletterController::class, 'unsubscribe']);
Route::post('/webhooks/paystack', [PaymentWebhookController::class, 'paystack']);
Route::post('/webhooks/flutterwave', [PaymentWebhookController::class, 'flutterwave']);
Route::post('/webhooks/stripe', [PaymentWebhookController::class, 'stripe']);
Route::post('/webhooks/paypal', [PaymentWebhookController::class, 'paypal']);

Route::get('/institutions/public', [InstitutionController::class, 'publicIndex']);
Route::get('/institutions/public/{institution}', [InstitutionController::class, 'publicShow']);
Route::get('/posts', [PostController::class, 'index']);
Route::get('/posts/{post}', [PostController::class, 'show'])->whereNumber('post');
Route::get('/posts/{post}/comments', [PostController::class, 'comments'])->whereNumber('post');
Route::get('/stories', [StoryController::class, 'index']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/me', [MeController::class, 'show']);
    Route::patch('/me', [MeController::class, 'update']);
    Route::get('/me/export', [MeController::class, 'export']);
    Route::delete('/me', [MeController::class, 'destroy']);
    Route::post('/me/attach-institution', [MeController::class, 'attachInstitution']);

    Route::get('/profiles/me', [ProfileController::class, 'me']);
    Route::patch('/profiles/me', [ProfileController::class, 'updateMe']);
    Route::get('/profiles/{user}', [ProfileController::class, 'show']);
    Route::patch('/profiles/{user}', [ProfileController::class, 'updateUser']);

    Route::post('/profiles/{user}/request-verification', [VerificationController::class, 'request']);
    Route::post('/profiles/{user}/verify', [VerificationController::class, 'verify']);
    Route::post('/profiles/{user}/reject', [VerificationController::class, 'reject']);
    Route::get('/admin/verification-requests', [VerificationController::class, 'index']);

    Route::post('/student-ids/generate', [StudentIdController::class, 'generate']);
    Route::post('/student-ids/request', [StudentIdController::class, 'request']);
    Route::post('/institutions/register', [InstitutionController::class, 'registerSchool']);
    Route::get('/institutions/me', [InstitutionController::class, 'me']);
    Route::patch('/institutions/me', [InstitutionController::class, 'updateMe']);
    Route::get('/institutions/me/payment-settings', [InstitutionPaymentSettingController::class, 'showMe']);
    Route::patch('/institutions/me/payment-settings', [InstitutionPaymentSettingController::class, 'updateMe']);
    Route::get('/institutions/me/email-settings', [InstitutionEmailSettingController::class, 'showMe']);
    Route::patch('/institutions/me/email-settings', [InstitutionEmailSettingController::class, 'updateMe']);
    Route::get('/admin/institutions/{institution}/payment-settings', [InstitutionPaymentSettingController::class, 'show']);
    Route::patch('/admin/institutions/{institution}/payment-settings', [InstitutionPaymentSettingController::class, 'update']);
    Route::get('/admin/platform-payment-settings', [PlatformPaymentSettingController::class, 'show']);
    Route::patch('/admin/platform-payment-settings', [PlatformPaymentSettingController::class, 'update']);
    Route::get('/admin/newsletter/subscribers', [NewsletterController::class, 'index']);
    Route::post('/admin/newsletter/send-launch', [NewsletterController::class, 'sendLaunch']);
    Route::get('/admin/newsletter/export', [NewsletterController::class, 'export']);
    Route::get('/admin/institutions/{institution}/email-settings', [InstitutionEmailSettingController::class, 'show']);
    Route::patch('/admin/institutions/{institution}/email-settings', [InstitutionEmailSettingController::class, 'update']);

    Route::post('/users/{user}/suspend', [UserAdminController::class, 'suspend']);
    Route::post('/users/{user}/reactivate', [UserAdminController::class, 'reactivate']);

    // Feeds + discovery
    Route::get('/feed/global', [FeedController::class, 'global']);
    Route::get('/feed/institutions/{institutionId}', [FeedController::class, 'institution']);
    Route::post('/announcements', [AnnouncementController::class, 'store'])->middleware('admin_permission:manage_announcements');
    Route::post('/calls/token', [CallController::class, 'token']);

    Route::get('/admin/announcements', [AnnouncementController::class, 'index'])->middleware('admin_permission:manage_announcements');
    Route::patch('/admin/announcements/{announcement}', [AnnouncementController::class, 'update'])->middleware('admin_permission:manage_announcements');
    Route::post('/admin/announcements/{announcement}/send-email', [AnnouncementController::class, 'sendEmail'])->middleware('admin_permission:manage_announcements');

    Route::post('/email/verification-notification', function (Request $request) {
        if ($request->user()->hasVerifiedEmail()) {
            return response()->json(['message' => 'Email already verified']);
        }

        $request->user()->sendEmailVerificationNotification();

        return response()->json(['message' => 'Verification link sent']);
    })->middleware('throttle:auth');

    // Institution community + moderation
    Route::post('/institutions/{institution}/join-request', [InstitutionMembershipController::class, 'requestJoin']);
    Route::get('/institutions/{institution}/join-requests', [InstitutionMembershipController::class, 'listRequests']);
    Route::post('/institutions/{institution}/join-requests/{membership}/approve', [InstitutionMembershipController::class, 'approve']);
    Route::post('/institutions/{institution}/join-requests/{membership}/reject', [InstitutionMembershipController::class, 'reject']);
    Route::get('/institutions/{institution}/year-groups', [InstitutionYearGroupController::class, 'index']);
    Route::post('/institutions/{institution}/year-groups', [InstitutionYearGroupController::class, 'store']);
    Route::post('/institutions/{institution}/year-groups/{group}/members', [InstitutionYearGroupController::class, 'addMember']);
    Route::post('/institutions/{institution}/year-groups/{group}/join', [InstitutionYearGroupController::class, 'requestJoin']);
    Route::get('/institutions/{institution}/year-group-requests', [InstitutionYearGroupController::class, 'listRequests']);
    Route::post('/institutions/{institution}/year-group-requests/{membership}/approve', [InstitutionYearGroupController::class, 'approve']);
    Route::post('/institutions/{institution}/year-group-requests/{membership}/reject', [InstitutionYearGroupController::class, 'reject']);
    Route::get('/institutions/{institution}/feed', [InstitutionController::class, 'feed']);
    Route::get('/institutions/{institution}/analytics', [InstitutionController::class, 'analytics']);

    // Events
    Route::get('/events', [EventController::class, 'index']);
    Route::post('/events', [EventController::class, 'store'])->middleware('admin_permission:manage_events');
    Route::get('/events/{event}', [EventController::class, 'show']);
    Route::patch('/events/{event}', [EventController::class, 'update'])->middleware('admin_permission:manage_events');
    Route::delete('/events/{event}', [EventController::class, 'destroy'])->middleware('admin_permission:manage_events');
    Route::delete('/admin/events/{event}/purge', [EventController::class, 'forceDestroy'])->middleware('admin_permission:manage_events');
    Route::post('/events/{event}/rsvp', [EventController::class, 'rsvp']);

    // Content system (posts)
    Route::get('/posts/scheduled', [PostController::class, 'scheduled']);
    Route::get('/posts/saved', [PostController::class, 'saved']);
    Route::get('/posts/hidden', [PostController::class, 'hidden']);
    Route::post('/posts', [PostController::class, 'store']);
    Route::post('/posts/{post}/publish-now', [PostController::class, 'publishNow']);
    Route::delete('/posts/{post}', [PostController::class, 'destroy']);

    Route::post('/posts/{post}/comments', [PostController::class, 'comment']);
    Route::post('/posts/comments/{comment}/like', [PostController::class, 'likeComment']);
    Route::delete('/posts/comments/{comment}/like', [PostController::class, 'unlikeComment']);

    Route::post('/posts/{post}/like', [PostController::class, 'like']);
    Route::delete('/posts/{post}/like', [PostController::class, 'unlike']);
    Route::post('/posts/{post}/repost', [PostController::class, 'repost']);
    Route::delete('/posts/{post}/repost', [PostController::class, 'unrepost']);
    Route::post('/posts/{post}/share', [PostController::class, 'share']);

    Route::post('/posts/{post}/report', [PostController::class, 'report']);
    Route::post('/posts/{post}/save', [PostController::class, 'save']);
    Route::delete('/posts/{post}/save', [PostController::class, 'unsave']);
    Route::post('/posts/{post}/hide', [PostController::class, 'hide']);
    Route::delete('/posts/{post}/hide', [PostController::class, 'unhide']);
    Route::post('/posts/{post}/pin', [PostController::class, 'pin']);
    Route::post('/posts/{post}/unpin', [PostController::class, 'unpin']);

    // Stories with 24h expiry + view counts
    Route::post('/stories', [StoryController::class, 'store']);
    Route::post('/stories/{story}/view', [StoryController::class, 'view']);
    Route::post('/stories/{story}/react', [StoryController::class, 'react']);
    Route::post('/stories/{story}/repost', [StoryController::class, 'repost']);
    Route::delete('/stories/{story}/repost', [StoryController::class, 'unrepost']);
    Route::post('/stories/{story}/share', [StoryController::class, 'share']);
    Route::post('/stories/{story}/reply', [StoryController::class, 'reply']);
    Route::get('/stories/{story}/reactions', [StoryController::class, 'reactions']);
    Route::get('/stories/{story}/views', [StoryController::class, 'views']);
    Route::delete('/stories/{story}', [StoryController::class, 'destroy']);
    Route::post('/stories/{story}/delete', [StoryController::class, 'destroy']);

    // Messaging + networking
    Route::get('/messages/threads', [MessageController::class, 'threads']);
    Route::get('/connections', [ConnectionController::class, 'index']);
    Route::post('/connections/{user}', [ConnectionController::class, 'send']);
    Route::post('/connections/{connection}/respond', [ConnectionController::class, 'respond']);
    Route::get('/messages/{user}', [MessageController::class, 'thread']);
    Route::post('/messages/{user}', [MessageController::class, 'send'])->middleware('throttle:messages');
    Route::post('/messages/direct/{message}/react', [MessageController::class, 'react']);
    Route::post('/messages/{user}/typing', [TypingController::class, 'dmTyping']);
    Route::get('/messages/{user}/typing', [TypingController::class, 'dmTypingStatus']);
    Route::get('/chat-preferences/{chatKey}', [ChatPreferenceController::class, 'show']);
    Route::patch('/chat-preferences/{chatKey}', [ChatPreferenceController::class, 'update']);
    Route::post('/media/upload', [MediaUploadController::class, 'store'])->middleware('throttle:upload');

    // Group chats
    Route::get('/group-chats', [GroupChatController::class, 'index']);
    Route::post('/group-chats', [GroupChatController::class, 'store']);
    Route::patch('/group-chats/{groupChat}', [GroupChatController::class, 'update']);
    Route::get('/group-chats/{groupChat}/members', [GroupChatController::class, 'members']);
    Route::delete('/group-chats/{groupChat}/members/{user}', [GroupChatController::class, 'removeMember']);
    Route::get('/group-chats/{groupChat}/messages', [GroupChatController::class, 'messages']);
    Route::post('/group-chats/{groupChat}/messages', [GroupChatController::class, 'sendMessage']);
    Route::post('/group-chats/messages/{message}/react', [GroupChatController::class, 'reactToMessage']);
    Route::post('/group-chats/{groupChat}/typing', [TypingController::class, 'groupTyping']);
    Route::get('/group-chats/{groupChat}/typing', [TypingController::class, 'groupTypingStatus']);

    // Blocking/reporting + moderation
    Route::post('/users/{user}/block', [UserSafetyController::class, 'block']);
    Route::delete('/users/{user}/block', [UserSafetyController::class, 'unblock']);
    Route::post('/users/{user}/report', [UserSafetyController::class, 'report']);
    Route::post('/users/{user}/mute', [UserSafetyController::class, 'mute']);
    Route::delete('/users/{user}/mute', [UserSafetyController::class, 'unmute']);
    Route::get('/users/muted', [UserSafetyController::class, 'muted']);
    Route::get('/moderation/user-reports', [ModerationController::class, 'userReports'])->middleware('admin_permission:manage_moderation');
    Route::post('/moderation/user-reports/{report}/resolve', [ModerationController::class, 'resolveUserReport'])->middleware('admin_permission:manage_moderation');
    Route::get('/moderation/post-reports', [ModerationController::class, 'postReports'])->middleware('admin_permission:manage_moderation');
    Route::post('/moderation/post-reports/{report}/resolve', [ModerationController::class, 'resolvePostReport'])->middleware('admin_permission:manage_moderation');
    Route::get('/moderation/analytics', [ModerationController::class, 'analytics'])->middleware('admin_permission:manage_moderation');
    Route::get('/moderation/reports-pdf', [ModerationController::class, 'exportPdf'])->middleware('admin_permission:manage_moderation');

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::get('/notification-preferences', [NotificationPreferenceController::class, 'show']);
    Route::patch('/notification-preferences', [NotificationPreferenceController::class, 'update']);
    Route::post('/notifications/push-token', [PushTokenController::class, 'store']);
    Route::delete('/notifications/push-token', [PushTokenController::class, 'destroy']);
    Route::post('/admin/notifications/broadcast', [AdminNotificationBroadcastController::class, 'store']);

    // Support tickets
    Route::get('/support/tickets', [SupportTicketController::class, 'index']);
    Route::post('/support/tickets', [SupportTicketController::class, 'store']);
    Route::post('/support/tickets/{ticket}/reply', [SupportTicketController::class, 'reply']);

    // Payments, donations, subscriptions
    Route::post('/payments/initiate', [PaymentController::class, 'initiate']);
    Route::get('/payments/history', [PaymentController::class, 'history']);
    Route::post('/payments/{transaction}/refund', [PaymentController::class, 'refund']);
    Route::post('/subscriptions', [PaymentController::class, 'subscribe']);

    Route::get('/donation-campaigns', [DonationCampaignController::class, 'index']);
    Route::post('/donation-campaigns', [DonationCampaignController::class, 'store'])->middleware('admin_permission:manage_donations');
    Route::get('/donation-campaigns/{campaign}', [DonationCampaignController::class, 'show']);
    Route::patch('/donation-campaigns/{campaign}', [DonationCampaignController::class, 'update'])->middleware('admin_permission:manage_donations');
    Route::delete('/donation-campaigns/{campaign}', [DonationCampaignController::class, 'destroy'])->middleware('admin_permission:manage_donations');
    Route::delete('/admin/donation-campaigns/{campaign}/purge', [DonationCampaignController::class, 'forceDestroy'])->middleware('admin_permission:manage_donations');
    Route::post('/donation-campaigns/{campaign}/donate', [DonationCampaignController::class, 'donate']);
    Route::get('/donation-campaigns/{campaign}/report', [DonationCampaignController::class, 'report']);
    Route::get('/donation-campaigns/{campaign}/donations', [DonationCampaignController::class, 'donations']);

    // Ads + monetization
    Route::get('/ads', [AdController::class, 'index']);
    Route::get('/ads/analytics', [AdController::class, 'analyticsSummary']);
    Route::post('/ads', [AdController::class, 'store'])->middleware('admin_permission:manage_ads');
    Route::patch('/ads/{ad}', [AdController::class, 'update'])->middleware('admin_permission:manage_ads');
    Route::delete('/ads/{ad}', [AdController::class, 'destroy'])->middleware('admin_permission:manage_ads');
    Route::post('/ads/serve', [AdController::class, 'serve']);
    Route::post('/ads/{ad}/click', [AdController::class, 'click']);
    Route::get('/ads/{ad}/analytics', [AdController::class, 'analytics']);
    Route::post('/ads/{ad}/hide', [AdController::class, 'hide']);
    Route::get('/ads/hidden', [AdController::class, 'hidden']);

    // AI recommendations and controls
    Route::get('/recommendations', [RecommendationController::class, 'index']);
    Route::post('/recommendations/{recommendation}/feedback', [RecommendationController::class, 'feedback']);
    Route::get('/ai/controls', [RecommendationController::class, 'controls']);
    Route::patch('/ai/controls', [RecommendationController::class, 'updateControls']);
    Route::get('/ai/performance', [RecommendationController::class, 'performance']);

    // Analytics and dashboards
    Route::post('/analytics/track', [AnalyticsController::class, 'track']);
    Route::get('/analytics/institutions/{institution}', [AnalyticsController::class, 'institution']);
    Route::get('/analytics/platform', [AnalyticsController::class, 'platform']);
    Route::get('/analytics/platform/schools-pdf', [AnalyticsController::class, 'exportPlatformSchoolsPdf']);
    Route::get('/analytics/content-performance', [AnalyticsController::class, 'contentPerformance']);
    Route::get('/analytics/user', [AnalyticsController::class, 'userOverview']);
    Route::get('/dashboard/institution', [DashboardController::class, 'institution']);
    Route::get('/dashboard/super', [DashboardController::class, 'super']);

    // Super admin
    Route::get('/admin/institutions', [AdminInstitutionController::class, 'index']);
    Route::post('/admin/institutions', [AdminInstitutionController::class, 'store']);
    Route::post('/admin/institutions/bulk-import', [AdminInstitutionController::class, 'bulkImport']);
    Route::patch('/admin/institutions/{institution}/status', [AdminInstitutionController::class, 'updateStatus'])->whereNumber('institution');
    Route::get('/admin/institutions/{institution}', [AdminInstitutionController::class, 'show'])->whereNumber('institution');
    Route::patch('/admin/institutions/{institution}', [AdminInstitutionController::class, 'update'])->whereNumber('institution');
    Route::post('/admin/users', [AdminUserController::class, 'store']);
    Route::get('/admin/users', [AdminUserController::class, 'index']);
    Route::patch('/admin/users/{user}', [AdminUserController::class, 'update']);
    Route::delete('/admin/users/{user}/purge', [AdminUserController::class, 'destroy']);

    Route::get('/admin/payments/transactions', [AdminPaymentController::class, 'transactions']);
    Route::post('/admin/payments/transactions/{transaction}/receipt', [AdminPaymentController::class, 'generateReceipt']);
    Route::post('/admin/payments/receipts/backfill', [AdminPaymentController::class, 'backfillReceipts']);
    Route::get('/admin/subscriptions', [AdminPaymentController::class, 'subscriptions']);
    Route::post('/admin/subscriptions/{subscription}/cancel', [AdminPaymentController::class, 'cancelSubscription']);

    Route::get('/admin/audit-logs', [AuditLogController::class, 'index'])->middleware('admin_permission:view_audit_logs');
    Route::get('/admin/settings', [SystemSettingController::class, 'index']);
    Route::get('/admin/role-config', [SystemSettingController::class, 'roleConfig']);
    Route::patch('/admin/settings', [SystemSettingController::class, 'update']);
    Route::post('/admin/settings/test-email', [SystemSettingController::class, 'testEmail']);
    Route::get('/admin/support/queue', [SupportController::class, 'queue']);
    Route::post('/admin/support/tickets/{ticket}/resolve', [SupportTicketController::class, 'resolve'])->middleware('admin_permission:manage_support_queue');

    // Jobs
    Route::get('/jobs', [JobController::class, 'index']);
    Route::post('/jobs/{job}/apply', [JobController::class, 'apply']);
    Route::get('/admin/jobs', [JobController::class, 'adminIndex'])->middleware('admin_permission:manage_jobs');
    Route::post('/admin/jobs', [JobController::class, 'store'])->middleware('admin_permission:manage_jobs');
    Route::patch('/admin/jobs/{job}', [JobController::class, 'update'])->middleware('admin_permission:manage_jobs');
    Route::delete('/admin/jobs/{job}', [JobController::class, 'destroy'])->middleware('admin_permission:manage_jobs');
    Route::post('/admin/jobs/import-csv', [JobController::class, 'importCsv'])->middleware('admin_permission:manage_jobs');
    Route::get('/admin/jobs/analytics', [JobController::class, 'analytics'])->middleware('admin_permission:manage_jobs');
});

Route::get('/directory', [DirectoryController::class, 'index'])->middleware('auth:sanctum');
Route::get('/institutions', [InstitutionController::class, 'index']);
