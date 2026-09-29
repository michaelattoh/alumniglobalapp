<?php

namespace App\Http\Middleware;

use App\Models\SystemSetting;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireAdminPermission
{
    private function defaultPermissions(): array
    {
        return [
            'manage_announcements' => true,
            'manage_events' => true,
            'manage_jobs' => true,
            'manage_donations' => true,
            'manage_ads' => true,
            'manage_support_queue' => true,
            'manage_moderation' => true,
            'view_audit_logs' => true,
            'view_users' => true,
            'view_transactions' => true,
            'manage_receipts' => true,
            'view_subscriptions' => true,
        ];
    }

    private function hasConfiguredPermission(User $user, string $permission): bool
    {
        if ($user->role === 'super_admin') {
            return true;
        }

        if ($user->role === 'accountant' && in_array($permission, ['view_transactions', 'manage_receipts', 'view_subscriptions', 'manage_support_queue'], true)) {
            return true;
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        if (is_array($roleCatalog) && is_array($roleCatalog[$user->role] ?? null)) {
            $roleConfig = $roleCatalog[$user->role];
            $permissions = is_array($roleConfig['permissions'] ?? null)
                ? $roleCatalog[$user->role]['permissions']
                : [];

            if (array_key_exists($permission, $permissions)) {
                return (bool) $permissions[$permission];
            }

            $portal = $roleConfig['portal'] ?? null;
            if ($portal === 'accounting' && in_array($permission, ['view_transactions', 'manage_receipts', 'view_subscriptions', 'manage_support_queue'], true)) {
                return true;
            }

            if ($portal === 'support' && $permission === 'manage_support_queue') {
                return true;
            }
        }

        if ($user->role === 'institution_admin') {
            $raw = SystemSetting::query()->where('key', 'admin_permissions')->value('value');
            $permissions = is_array($raw) ? $raw : [];
            if (array_key_exists($permission, $permissions)) {
                return (bool) $permissions[$permission];
            }
            $defaults = $this->defaultPermissions();
            return (bool) ($defaults[$permission] ?? false);
        }

        return false;
    }

    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        $hasConfiguredRole = is_array($roleCatalog) && array_key_exists($user->role, $roleCatalog);
        if (!in_array($user->role, ['super_admin', 'institution_admin', 'accountant', 'support_agent'], true) && !$hasConfiguredRole) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if (!$this->hasConfiguredPermission($user, $permission)) {
            return response()->json(['message' => 'Permission denied'], 403);
        }

        return $next($request);
    }
}
