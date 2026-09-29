<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AdminUserController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        if (!$this->canViewUsers($actor)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $search = trim((string) $request->query('search', ''));
        $role = $request->query('role');
        $status = $request->query('status');
        $institutionId = $request->query('institution_id');

        $query = User::query()->with('institution:id,name')->orderByDesc('created_at');

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($role) {
            $query->where('role', $role);
        }

        if ($status) {
            $query->where('status', $status);
        }

        if ($institutionId) {
            $query->where('institution_id', (int) $institutionId);
        }

        $perPage = (int) $request->query('per_page', 20);
        $page = $query->paginate($perPage);

        return response()->json([
            'data' => $page->items(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $allowedRoles = $this->assignableRoles();
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:160', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'role' => ['required', 'string', 'in:' . implode(',', $allowedRoles)],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
        ]);

        if ($data['role'] === 'institution_admin' && empty($data['institution_id'])) {
            return response()->json(['message' => 'Institution is required for institution admins'], 422);
        }

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'role' => $data['role'],
            'institution_id' => $data['institution_id'] ?? null,
            'status' => 'active',
        ]);

        $user->profile()->firstOrCreate([], [
            'verification_status' => 'verified',
            'visibility' => 'public',
        ]);

        AuditLog::record($actor, 'admin.created', User::class, $user->id, [
            'role' => $data['role'],
        ], $request);

        return response()->json([
            'message' => 'Admin created',
            'user' => $user->load('institution:id,name'),
        ], 201);
    }

    public function destroy(Request $request, User $user)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot delete your own account'], 422);
        }

        $user->tokens()->delete();
        $user->delete();

        AuditLog::record($actor, 'user.deleted', User::class, $user->id, [], $request);

        return response()->json(['message' => 'User deleted']);
    }

    public function update(Request $request, User $user)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot update your own account'], 422);
        }

        $allowedRoles = array_merge(['alumni'], $this->assignableRoles());
        $data = $request->validate([
            'role' => ['nullable', 'string', 'in:' . implode(',', $allowedRoles)],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'status' => ['nullable', 'string', 'in:active,suspended'],
        ]);

        if (($data['role'] ?? null) === 'institution_admin' && empty($data['institution_id'])) {
            return response()->json(['message' => 'Institution is required for institution admins'], 422);
        }

        $updates = array_filter($data, fn($v) => $v !== null);
        if (!empty($updates)) {
            $user->update($updates);

            AuditLog::record($actor, 'user.updated', User::class, $user->id, $updates, $request);
        }

        return response()->json([
            'message' => 'User updated',
            'user' => $user->fresh()->load('institution:id,name'),
        ]);
    }

    private function canViewUsers(User $actor): bool
    {
        if ($actor->role === 'super_admin' || $actor->role === 'support_agent') {
            return true;
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        if (is_array($roleCatalog) && is_array($roleCatalog[$actor->role] ?? null)) {
            $permissions = is_array($roleCatalog[$actor->role]['permissions'] ?? null)
                ? $roleCatalog[$actor->role]['permissions']
                : [];
            return (bool) ($permissions['view_users'] ?? false);
        }

        return false;
    }

    private function assignableRoles(): array
    {
        $builtIn = ['super_admin', 'institution_admin', 'accountant', 'support_agent'];
        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        if (!is_array($roleCatalog)) {
            return $builtIn;
        }

        $custom = array_values(array_filter(array_keys($roleCatalog), function ($role) {
            return is_string($role) && $role !== '' && $role !== 'alumni';
        }));

        return array_values(array_unique(array_merge($builtIn, $custom)));
    }
}
