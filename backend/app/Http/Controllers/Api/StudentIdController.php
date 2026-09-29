<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StudentIdGenerateRequest;
use App\Http\Requests\Api\StudentIdRequest;
use App\Models\Institution;
use App\Models\StudentId;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class StudentIdController extends Controller
{
    public function generate(StudentIdGenerateRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $institution = Institution::where('id', $data['institution_id'])
            ->where('status', 'active')
            ->first();

        if (!$institution) {
            return response()->json(['message' => 'Institution not found or inactive'], 422);
        }

        $studentId = StudentId::where('institution_id', $institution->id)
            ->where('user_id', $user->id)
            ->where('status', 'issued')
            ->first();

        if (!$studentId) {
            $studentId = StudentId::create([
                'institution_id' => $institution->id,
                'user_id' => $user->id,
                'code' => $this->makeCode($institution->name),
                'full_name' => $user->name,
                'email' => $user->email,
                'status' => 'issued',
                'issued_at' => now(),
            ]);
        }

        return response()->json([
            'message' => 'Student ID generated',
            'code' => $studentId->code,
            'institution' => [
                'id' => $institution->id,
                'name' => $institution->name,
            ],
        ]);
    }

    public function request(StudentIdRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $institution = Institution::where('id', $data['institution_id'])
            ->where('status', 'active')
            ->first();

        if (!$institution) {
            return response()->json(['message' => 'Institution not found or inactive'], 422);
        }

        $studentId = StudentId::create([
            'institution_id' => $institution->id,
            'user_id' => $user->id,
            'code' => $this->makeCode($institution->name),
            'full_name' => $data['full_name'],
            'email' => $data['email'],
            'status' => 'issued',
            'issued_at' => now(),
        ]);

        return response()->json([
            'message' => 'Request received. Your school will send your ID to you.',
            'request_id' => $studentId->id,
        ], 201);
    }

    private function makeCode(string $institutionName): string
    {
        $prefix = Str::upper(Str::substr(preg_replace('/[^A-Za-z]/', '', $institutionName), 0, 3));
        $rand = Str::upper(Str::random(6));
        return ($prefix ?: 'SCH') . '-' . $rand;
    }
}
