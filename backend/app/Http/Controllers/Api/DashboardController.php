<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ad;
use App\Models\DonationCampaign;
use App\Models\Event;
use App\Models\PaymentTransaction;
use App\Models\Post;
use App\Models\Recommendation;
use App\Models\User;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function institution(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'institution_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $institutionId = $actor->institution_id;

        return response()->json([
            'kpis' => [
                'members' => User::where('institution_id', $institutionId)->count(),
                'posts' => Post::where('institution_id', $institutionId)->count(),
                'events' => Event::where('institution_id', $institutionId)->count(),
                'active_campaigns' => DonationCampaign::where('institution_id', $institutionId)->where('is_active', true)->count(),
                'revenue' => (float) PaymentTransaction::where('institution_id', $institutionId)->where('status', 'success')->sum('amount'),
            ],
        ]);
    }

    public function super(Request $request)
    {
        if ($request->user()->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        return response()->json([
            'kpis' => [
                'users' => User::count(),
                'institutions' => \App\Models\Institution::count(),
                'transactions' => PaymentTransaction::count(),
                'ads_active' => Ad::where('status', 'active')->count(),
                'recommendations_served' => Recommendation::whereNotNull('served_at')->count(),
            ],
            'controls' => [
                'can_manage_ai' => true,
                'can_manage_pricing' => true,
                'can_manage_ads' => true,
            ],
        ]);
    }
}
