<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\JobApplicationStoreRequest;
use App\Http\Resources\Api\JobResource;
use App\Models\JobApplication;
use App\Models\Job;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class JobController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Job::query()
            ->where('is_active', true)
            ->with('institution:id,name,slug,status')
            ->orderByDesc('published_at')
            ->orderByDesc('created_at');

        if ($request->filled('category')) {
            $query->where('category', $request->query('category'));
        }

        if ($request->filled('q')) {
            $q = $request->query('q');
            $query->where(function ($sub) use ($q) {
                $sub->where('title', 'like', '%' . $q . '%')
                    ->orWhere('company_name', 'like', '%' . $q . '%')
                    ->orWhere('location', 'like', '%' . $q . '%');
            });
        }

        if ($user->role !== 'super_admin' && $user->institution_id) {
            $query->where(function ($sub) use ($user) {
                $sub->whereNull('institution_id')
                    ->orWhere('institution_id', $user->institution_id);
            });
        }

        $jobs = $query->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($jobs, JobResource::class);
    }

    public function apply(JobApplicationStoreRequest $request, Job $job)
    {
        if (!$job->is_active) {
            return response()->json(['message' => 'Job is no longer accepting applications'], 422);
        }

        $data = $request->validated();
        $application = JobApplication::create([
            'job_id' => $job->id,
            'user_id' => $request->user()->id,
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'linkedin_url' => $data['linkedin_url'] ?? null,
            'resume_url' => $data['resume_url'],
            'status' => 'submitted',
        ]);

        return response()->json([
            'message' => 'Application submitted',
            'application_id' => $application->id,
        ], 201);
    }

    public function adminIndex(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = Job::query()
            ->with('institution:id,name,slug,status')
            ->orderByDesc('published_at')
            ->orderByDesc('created_at');

        if ($actor->role === 'institution_admin') {
            $query->where('institution_id', $actor->institution_id);
        } elseif ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        if ($request->filled('category')) {
            $query->where('category', $request->query('category'));
        }

        if ($request->filled('status')) {
            $query->where('is_active', $request->query('status') === 'active');
        }

        if ($request->filled('q')) {
            $q = $request->query('q');
            $query->where(function ($sub) use ($q) {
                $sub->where('title', 'like', '%' . $q . '%')
                    ->orWhere('company_name', 'like', '%' . $q . '%')
                    ->orWhere('location', 'like', '%' . $q . '%');
            });
        }

        $jobs = $query->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($jobs, JobResource::class);
    }

    public function store(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:180'],
            'category' => ['nullable', 'string', 'max:80'],
            'company_name' => ['nullable', 'string', 'max:180'],
            'location' => ['nullable', 'string', 'max:120'],
            'work_mode' => ['nullable', 'string', 'in:remote,onsite,hybrid'],
            'salary' => ['nullable', 'string', 'max:120'],
            'experience_level' => ['nullable', 'string', 'in:entry,mid,senior,lead'],
            'overview' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],
            'expectations' => ['nullable', 'array'],
            'requirements' => ['nullable', 'array'],
            'company_overview' => ['nullable', 'string'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'is_active' => ['nullable', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);

        $institutionId = $data['institution_id'] ?? $actor->institution_id;
        if ($actor->role === 'institution_admin' && (int) $institutionId !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $job = Job::create([
            'institution_id' => $institutionId,
            'title' => $data['title'],
            'category' => $data['category'] ?? null,
            'company_name' => $data['company_name'] ?? null,
            'location' => $data['location'] ?? null,
            'work_mode' => $data['work_mode'] ?? null,
            'salary' => $data['salary'] ?? null,
            'experience_level' => $data['experience_level'] ?? null,
            'overview' => $data['overview'] ?? null,
            'description' => $data['description'] ?? null,
            'expectations' => $data['expectations'] ?? null,
            'requirements' => $data['requirements'] ?? null,
            'company_overview' => $data['company_overview'] ?? null,
            'is_active' => $data['is_active'] ?? true,
            'published_at' => $data['published_at'] ?? now(),
        ]);

        return response()->json([
            'message' => 'Job created',
            'job' => new JobResource($job->load('institution:id,name,slug,status')),
        ], 201);
    }

    public function update(Request $request, Job $job)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $job->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $data = $request->validate([
            'title' => ['nullable', 'string', 'max:180'],
            'category' => ['nullable', 'string', 'max:80'],
            'company_name' => ['nullable', 'string', 'max:180'],
            'location' => ['nullable', 'string', 'max:120'],
            'work_mode' => ['nullable', 'string', 'in:remote,onsite,hybrid'],
            'salary' => ['nullable', 'string', 'max:120'],
            'experience_level' => ['nullable', 'string', 'in:entry,mid,senior,lead'],
            'overview' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],
            'expectations' => ['nullable', 'array'],
            'requirements' => ['nullable', 'array'],
            'company_overview' => ['nullable', 'string'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'is_active' => ['nullable', 'boolean'],
            'published_at' => ['nullable', 'date'],
        ]);

        if ($actor->role === 'institution_admin' && isset($data['institution_id']) && (int) $data['institution_id'] !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $job->update($data);

        return response()->json([
            'message' => 'Job updated',
            'job' => new JobResource($job->fresh()->load('institution:id,name,slug,status')),
        ]);
    }

    public function destroy(Request $request, Job $job)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $job->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $job->delete();

        return response()->json(['message' => 'Job deleted']);
    }

    public function analytics(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = Job::query();
        if ($actor->role === 'institution_admin') {
            $query->where('institution_id', $actor->institution_id);
        } elseif ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        $rows = $query
            ->selectRaw('COALESCE(category, "Uncategorized") as category, COUNT(*) as total')
            ->groupBy('category')
            ->orderByDesc('total')
            ->get();

        return response()->json([
            'data' => $rows,
        ]);
    }

    public function importCsv(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'file' => ['required', 'file'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
        ]);

        $institutionId = $data['institution_id'] ?? $actor->institution_id;
        if ($actor->role === 'institution_admin' && (int) $institutionId !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $path = $request->file('file')->getRealPath();
        if (!$path || !file_exists($path)) {
            return response()->json(['message' => 'Invalid file'], 422);
        }

        $handle = fopen($path, 'r');
        if ($handle === false) {
            return response()->json(['message' => 'Unable to read file'], 422);
        }

        $header = fgetcsv($handle);
        if (!$header) {
            fclose($handle);
            return response()->json(['message' => 'Empty CSV'], 422);
        }

        $header = array_map(fn($h) => strtolower(trim((string) $h)), $header);
        $created = 0;
        $errors = [];
        $lineNumber = 1;

        while (($row = fgetcsv($handle)) !== false) {
            $lineNumber++;
            $payload = array_combine($header, $row);
            if (!$payload) {
                $errors[] = ['row_number' => $lineNumber, 'row' => $row, 'error' => 'Invalid row'];
                continue;
            }

            $validator = Validator::make($payload, [
                'title' => ['required', 'string', 'max:180'],
                'category' => ['nullable', 'string', 'max:80'],
                'company_name' => ['nullable', 'string', 'max:180'],
                'location' => ['nullable', 'string', 'max:120'],
                'work_mode' => ['nullable', 'string', 'in:remote,onsite,hybrid'],
                'salary' => ['nullable', 'string', 'max:120'],
                'experience_level' => ['nullable', 'string', 'in:entry,mid,senior,lead'],
                'overview' => ['nullable', 'string'],
                'description' => ['nullable', 'string'],
                'is_active' => ['nullable'],
                'published_at' => ['nullable', 'date'],
            ]);

            if ($validator->fails()) {
                $errors[] = ['row_number' => $lineNumber, 'row' => $payload, 'error' => $validator->errors()->first()];
                continue;
            }

            Job::create([
                'institution_id' => $institutionId,
                'title' => $payload['title'],
                'category' => $payload['category'] ?? null,
                'company_name' => $payload['company_name'] ?? null,
                'location' => $payload['location'] ?? null,
                'work_mode' => $payload['work_mode'] ?? null,
                'salary' => $payload['salary'] ?? null,
                'experience_level' => $payload['experience_level'] ?? null,
                'overview' => $payload['overview'] ?? null,
                'description' => $payload['description'] ?? null,
                'is_active' => isset($payload['is_active'])
                    ? filter_var($payload['is_active'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? true
                    : true,
                'published_at' => $payload['published_at'] ?? now(),
            ]);
            $created++;
        }

        fclose($handle);

        return response()->json([
            'message' => 'Import complete',
            'created' => $created,
            'errors' => $errors,
        ]);
    }
}
