<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class BlockRestrictedInstitutionActions
{
    /**
     * Mutating routes that should remain available even when an institution is
     * on hold, so affected users can still log out and contact support.
     */
    private array $allowedPatterns = [
        'api/auth/logout',
        'api/support/tickets',
        'api/support/tickets/*/reply',
        'api/notifications/push-token',
        'api/notification-preferences',
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || $request->isMethodSafe() || $request->isMethod('OPTIONS')) {
            return $next($request);
        }

        foreach ($this->allowedPatterns as $pattern) {
            if ($request->is($pattern)) {
                return $next($request);
            }
        }

        $institution = $user->relationLoaded('institution')
            ? $user->institution
            : $user->institution()->first();

        $status = strtolower((string) optional($institution)->status);

        if (in_array($status, ['on_hold', 'suspended'], true)) {
            return response()->json([
                'message' => 'Access temporarily restricted. Your organization account is currently on hold. Please contact support for assistance.',
                'institution_status' => $status,
            ], 423);
        }

        return $next($request);
    }
}
