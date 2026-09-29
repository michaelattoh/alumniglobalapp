<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AdminInstitutionCreateRequest;
use App\Http\Requests\Api\AdminInstitutionStatusRequest;
use App\Http\Requests\Api\InstitutionProfileUpdateRequest;
use App\Models\AuditLog;
use App\Models\Institution;
use Illuminate\Support\Facades\Validator;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class AdminInstitutionController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $search = trim((string) $request->query('search', ''));
        $status = $request->query('status');

        $query = Institution::query()
            ->withCount('users')
            ->withCount(['users as admins_count' => function ($q) {
                $q->where('role', 'institution_admin');
            }])
            ->orderByDesc('created_at');

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('slug', 'like', "%{$search}%")
                  ->orWhere('school_id', 'like', "%{$search}%");
            });
        }

        if ($status) {
            $query->where('status', $status);
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

    public function updateStatus(AdminInstitutionStatusRequest $request, Institution $institution)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $status = $request->validated()['status'];
        $institution->status = $status;
        $institution->save();

        AuditLog::record($actor, 'institution.status_updated', Institution::class, $institution->id, [
            'status' => $status,
        ], $request);

        return response()->json([
            'message' => 'Institution updated',
            'institution' => $institution,
        ]);
    }

    public function store(AdminInstitutionCreateRequest $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();
        $status = $data['status'] ?? 'pending';
        $name = $data['name'];

        $institution = Institution::create([
            'name' => $name,
            'school_id' => $this->generateSchoolId(),
            'slug' => $this->generateUniqueSlug($name),
            'status' => $status,
            'website' => $data['website'] ?? null,
            'email' => $data['email'] ?? null,
            'phone' => $data['phone'] ?? null,
            'location' => $data['location'] ?? null,
            'address' => $data['address'] ?? null,
            'motto' => $data['motto'] ?? null,
            'description' => $data['description'] ?? null,
        ]);

        AuditLog::record($actor, 'institution.created', Institution::class, $institution->id, [
            'status' => $status,
        ], $request);

        return response()->json([
            'message' => 'Institution created',
            'institution' => $institution,
        ], 201);
    }

    public function bulkImport(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $validator = Validator::make($request->all(), [
            'rows' => ['required', 'array', 'min:1'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Invalid bulk import payload',
                'errors' => $validator->errors(),
            ], 422);
        }

        $rows = collect($request->input('rows', []))
            ->map(fn ($row) => is_array($row) ? $row : [])
            ->values();

        $rowRules = [
            'name' => ['required', 'string', 'max:255'],
            'website' => ['nullable', 'string', 'max:200'],
            'email' => ['nullable', 'email', 'max:200'],
            'phone' => ['nullable', 'string', 'max:80'],
            'location' => ['nullable', 'string', 'max:120'],
            'address' => ['nullable', 'string', 'max:200'],
            'motto' => ['nullable', 'string', 'max:160'],
            'description' => ['nullable', 'string', 'max:2000'],
        ];

        $existingNames = Institution::query()
            ->pluck('name')
            ->filter()
            ->mapWithKeys(fn ($value) => [$this->normalizeImportValue($value) => true]);
        $existingEmails = Institution::query()
            ->pluck('email')
            ->filter()
            ->mapWithKeys(fn ($value) => [$this->normalizeImportValue($value) => true]);
        $existingWebsites = Institution::query()
            ->pluck('website')
            ->filter()
            ->mapWithKeys(fn ($value) => [$this->normalizeImportValue($value) => true]);

        $seenNames = [];
        $seenEmails = [];
        $seenWebsites = [];
        $created = [];
        $report = [];

        foreach ($rows as $index => $row) {
            $rowNumber = $index + 2;
            $rowValidator = Validator::make($row, $rowRules);
            if ($rowValidator->fails()) {
                $report[] = [
                    'row' => $rowNumber,
                    'status' => 'error',
                    'name' => $row['name'] ?? null,
                    'message' => implode(' ', $rowValidator->errors()->all()),
                ];
                continue;
            }

            $data = $rowValidator->validated();
            $name = trim((string) $data['name']);
            $normalizedName = $this->normalizeImportValue($name);
            $normalizedEmail = $this->normalizeImportValue($data['email'] ?? null);
            $normalizedWebsite = $this->normalizeImportValue($data['website'] ?? null);

            $duplicateReasons = [];
            if ($normalizedName !== '' && (isset($seenNames[$normalizedName]) || $existingNames->has($normalizedName))) {
                $duplicateReasons[] = 'Duplicate school name';
            }
            if ($normalizedEmail !== '' && (isset($seenEmails[$normalizedEmail]) || $existingEmails->has($normalizedEmail))) {
                $duplicateReasons[] = 'Duplicate school email';
            }
            if ($normalizedWebsite !== '' && (isset($seenWebsites[$normalizedWebsite]) || $existingWebsites->has($normalizedWebsite))) {
                $duplicateReasons[] = 'Duplicate school website';
            }

            if ($duplicateReasons !== []) {
                $report[] = [
                    'row' => $rowNumber,
                    'status' => 'skipped',
                    'name' => $name,
                    'message' => implode('; ', $duplicateReasons),
                ];
                continue;
            }

            $institution = Institution::create([
                'name' => $name,
                'school_id' => $this->generateSchoolId(),
                'slug' => $this->generateUniqueSlug($name),
                'status' => 'suspended',
                'website' => $data['website'] ?? null,
                'email' => $data['email'] ?? null,
                'phone' => $data['phone'] ?? null,
                'location' => $data['location'] ?? null,
                'address' => $data['address'] ?? null,
                'motto' => $data['motto'] ?? null,
                'description' => $data['description'] ?? null,
            ]);
            $created[] = $institution;

            if ($normalizedName !== '') {
                $seenNames[$normalizedName] = true;
            }
            if ($normalizedEmail !== '') {
                $seenEmails[$normalizedEmail] = true;
            }
            if ($normalizedWebsite !== '') {
                $seenWebsites[$normalizedWebsite] = true;
            }

            $report[] = [
                'row' => $rowNumber,
                'status' => 'imported',
                'name' => $institution->name,
                'school_id' => $institution->school_id,
                'message' => 'Imported successfully',
            ];
        }

        AuditLog::record($actor, 'institution.bulk_imported', Institution::class, null, [
            'count' => count($created),
            'institution_ids' => collect($created)->pluck('id')->all(),
        ], $request);

        return response()->json([
            'message' => 'Institutions imported',
            'count' => count($created),
            'skipped_count' => collect($report)->where('status', 'skipped')->count(),
            'error_count' => collect($report)->where('status', 'error')->count(),
            'institutions' => $created,
            'report' => $report,
        ], 201);
    }

    public function show(Request $request, Institution $institution)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        return response()->json([
            'institution' => $institution,
        ]);
    }

    public function update(InstitutionProfileUpdateRequest $request, Institution $institution)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $institution->update($request->validated());

        AuditLog::record($actor, 'institution.profile_updated', Institution::class, $institution->id, [
            'fields' => array_keys($request->validated()),
        ], $request);

        return response()->json([
            'message' => 'Institution profile updated',
            'institution' => $institution->fresh(),
        ]);
    }

    private function generateUniqueSlug(string $name): string
    {
        $base = Str::slug($name);
        if ($base === '') {
            $base = Str::lower(Str::random(8));
        }

        $slug = $base;
        $suffix = 1;

        while (Institution::where('slug', $slug)->exists()) {
            $suffix++;
            $slug = "{$base}-{$suffix}";
        }

        return $slug;
    }

    private function generateSchoolId(): string
    {
        do {
            $code = 'SCH-' . Str::upper(Str::random(6));
        } while (Institution::where('school_id', $code)->exists());

        return $code;
    }

    private function normalizeImportValue(mixed $value): string
    {
        return Str::of((string) ($value ?? ''))
            ->lower()
            ->trim()
            ->value();
    }
}
