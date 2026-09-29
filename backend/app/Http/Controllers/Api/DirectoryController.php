<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InstitutionMembership;
use App\Models\User;
use Illuminate\Http\Request;

class DirectoryController extends Controller
{
    public function index(Request $request)
    {
        $viewer = $request->user();

        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'institution_id' => ['nullable', 'integer'],
            'graduation_year' => ['nullable', 'integer', 'min:1950', 'max:' . (int) now()->format('Y')],
            'industry' => ['nullable', 'string', 'max:120'],
            'program' => ['nullable', 'string', 'max:120'],
            'department' => ['nullable', 'string', 'max:120'],
            'location' => ['nullable', 'string', 'max:120'],
            'skills' => ['nullable', 'array', 'max:10'],
            'skills.*' => ['string', 'max:50'],
            'verified_only' => ['nullable', 'boolean'],
            'visibility' => ['nullable', 'string', 'in:public,institution_only'],
            'per_page' => ['nullable', 'integer', 'min:5', 'max:50'],
            'page' => ['nullable', 'integer', 'min:1'],
            'sort' => ['nullable', 'string', 'in:recent,az'],
        ]);

        $perPage = $data['per_page'] ?? 20;

        // Base query: users who have profiles
        $query = User::query()
            ->select([
                'users.id', 'users.name', 'users.email', 'users.role', 'users.institution_id',
                'profiles.headline', 'profiles.avatar_url', 'profiles.location',
                'profiles.graduation_year', 'profiles.program', 'profiles.department',
                'profiles.current_company', 'profiles.current_role',
                'profiles.industry', 'profiles.career_focus',
                'profiles.skills', 'profiles.interests', 'profiles.visibility', 'profiles.verification_status', 'profiles.verified_at',
            ])
            ->join('profiles', 'profiles.user_id', '=', 'users.id');

        // Never return the signed-in user in directory/suggestion results.
        $query->where('users.id', '!=', $viewer->id);

        /**
         * Role-based visibility rules
         * - super_admin: can see everything
         * - everyone else:
         *   - public profiles always visible
         *   - institution_only visible only if same institution
         */
        if ($viewer->role !== 'super_admin') {
            $query->where(function ($q) use ($viewer) {
                $q->where('profiles.visibility', 'public');

                if ($viewer->institution_id) {
                    $q->orWhere(function ($q2) use ($viewer) {
                        $q2->where('profiles.visibility', 'institution_only')
                           ->where('users.institution_id', $viewer->institution_id);
                    });
                }
            });
        }

        /**
         * Default institution admin scope (sensible default)
         * Institution admins usually care about their own institution.
         * They can still override by passing institution_id, but we default it.
         */
        if (in_array($viewer->role, ['institution_admin', 'admin'], true) && empty($data['institution_id']) && $viewer->institution_id) {
            $query->where(function ($scoped) use ($viewer) {
                $scoped->where('users.institution_id', $viewer->institution_id)
                    ->orWhereExists(function ($membershipQuery) use ($viewer) {
                        $membershipQuery
                            ->selectRaw('1')
                            ->from('institution_memberships')
                            ->whereColumn('institution_memberships.user_id', 'users.id')
                            ->where('institution_memberships.institution_id', $viewer->institution_id)
                            ->where('institution_memberships.status', 'approved');
                    });
            });
        }

        // Filters
        if (!empty($data['institution_id'])) {
            $query->where(function ($scoped) use ($data) {
                $scoped->where('users.institution_id', $data['institution_id'])
                    ->orWhereExists(function ($membershipQuery) use ($data) {
                        $membershipQuery
                            ->selectRaw('1')
                            ->from('institution_memberships')
                            ->whereColumn('institution_memberships.user_id', 'users.id')
                            ->where('institution_memberships.institution_id', $data['institution_id'])
                            ->where('institution_memberships.status', 'approved');
                    });
            });
        }

        if (!empty($data['graduation_year'])) {
            $query->where('profiles.graduation_year', $data['graduation_year']);
        }

        if (!empty($data['industry'])) {
            $query->where('profiles.industry', 'like', '%' . $this->escapeLike($data['industry']) . '%');
        }

        if (!empty($data['program'])) {
            $query->where('profiles.program', 'like', '%' . $this->escapeLike($data['program']) . '%');
        }

        if (!empty($data['department'])) {
            $query->where('profiles.department', 'like', '%' . $this->escapeLike($data['department']) . '%');
        }

        if (!empty($data['location'])) {
            $query->where('profiles.location', 'like', '%' . $this->escapeLike($data['location']) . '%');
        }

        if (!empty($data['skills'])) {
            foreach ($data['skills'] as $skill) {
                $query->whereJsonContains('profiles.skills', $skill);
            }
        }

        if (!empty($data['visibility'])) {
            $query->where('profiles.visibility', $data['visibility']);
        }

        if (($data['verified_only'] ?? false) === true) {
            $query->where('profiles.verification_status', 'verified');
        }

        // Search query (name + headline + company + role)
        if (!empty($data['q'])) {
            $q = $this->escapeLike($data['q']);
            $query->where(function ($sub) use ($q) {
                $sub->where('users.name', 'like', "%{$q}%")
                    ->orWhere('profiles.headline', 'like', "%{$q}%")
                    ->orWhere('profiles.current_company', 'like', "%{$q}%")
                    ->orWhere('profiles.current_role', 'like', "%{$q}%")
                    ->orWhere('profiles.industry', 'like', "%{$q}%")
                    ->orWhere('profiles.program', 'like', "%{$q}%")
                    ->orWhere('profiles.department', 'like', "%{$q}%");
            });
        }

        // Sorting
        $sort = $data['sort'] ?? 'recent';
        if ($sort === 'az') {
            $query->orderBy('users.name');
        } else {
            $query->orderByDesc('profiles.verified_at')
                  ->orderByDesc('users.id');
        }

        $results = $query->paginate($perPage);

        return response()->json([
            'meta' => [
                'page' => $results->currentPage(),
                'per_page' => $results->perPage(),
                'total' => $results->total(),
                'last_page' => $results->lastPage(),
            ],
            'data' => $results->items(),
        ]);
    }

    private function escapeLike(string $value): string
    {
        // escape % and _ for LIKE queries
        return addcslashes($value, '\%_');
    }
}
