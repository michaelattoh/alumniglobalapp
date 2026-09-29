<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->redirectGuestsTo(function (Request $request) {
            if ($request->is('api/*') || $request->expectsJson()) {
                return null;
            }

            return '/login';
        });

        $middleware->alias([
            'role' => \App\Http\Middleware\RequireRole::class,
            'active_user' => \App\Http\Middleware\BlockSuspendedUsers::class,
            'admin_permission' => \App\Http\Middleware\RequireAdminPermission::class,
            'institution_access' => \App\Http\Middleware\BlockRestrictedInstitutionActions::class,
        ]);

        $middleware->group('api', [
            \Illuminate\Http\Middleware\HandleCors::class,
            \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
            \App\Http\Middleware\BlockSuspendedUsers::class,
            \App\Http\Middleware\BlockRestrictedInstitutionActions::class,
            \App\Http\Middleware\SecurityHeaders::class,
            'throttle:api',
        ]);

    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*') || $request->expectsJson()) {
                return response()->json(['message' => 'Unauthenticated'], 401);
            }

            throw $e;
        });
    })
    ->create();
