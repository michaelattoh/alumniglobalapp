<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\AuditLogResource;
use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = AuditLog::query()->with('actor:id,name,email,institution_id')->latest();

        if ($actor->role === 'institution_admin') {
            $query->whereHas('actor', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            });
        }

        if ($request->filled('action')) {
            $query->where('action', $request->query('action'));
        }

        if ($request->filled('entity_type')) {
            $query->where('entity_type', $request->query('entity_type'));
        }

        if ($request->filled('actor_id')) {
            $query->where('actor_id', $request->query('actor_id'));
        }

        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->query('from'));
        }

        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->query('to'));
        }

        $logs = $query->paginate((int) $request->query('per_page', 30));

        return $this->paginatedResponse($logs, AuditLogResource::class);
    }
}
