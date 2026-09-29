<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\InstitutionEmailSettingUpdateRequest;
use App\Models\Institution;
use App\Models\InstitutionEmailSetting;
use Illuminate\Http\Request;

class InstitutionEmailSettingController extends Controller
{
    public function showMe(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'institution_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if (!$actor->institution_id) {
            return response()->json(['message' => 'Institution not assigned'], 422);
        }

        $settings = InstitutionEmailSetting::firstOrCreate([
            'institution_id' => $actor->institution_id,
        ]);

        return response()->json([
            'institution_id' => $actor->institution_id,
            'settings' => $this->format($settings),
        ]);
    }

    public function updateMe(InstitutionEmailSettingUpdateRequest $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'institution_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if (!$actor->institution_id) {
            return response()->json(['message' => 'Institution not assigned'], 422);
        }

        $settings = InstitutionEmailSetting::firstOrCreate([
            'institution_id' => $actor->institution_id,
        ]);

        $this->applySettings($settings, $request->validated());

        return response()->json([
            'message' => 'Email settings updated',
            'settings' => $this->format($settings),
        ]);
    }

    public function show(Request $request, Institution $institution)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $settings = InstitutionEmailSetting::firstOrCreate([
            'institution_id' => $institution->id,
        ]);

        return response()->json([
            'institution_id' => $institution->id,
            'settings' => $this->format($settings),
        ]);
    }

    public function update(InstitutionEmailSettingUpdateRequest $request, Institution $institution)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $settings = InstitutionEmailSetting::firstOrCreate([
            'institution_id' => $institution->id,
        ]);

        $this->applySettings($settings, $request->validated());

        return response()->json([
            'message' => 'Email settings updated',
            'settings' => $this->format($settings),
        ]);
    }

    private function applySettings(InstitutionEmailSetting $settings, array $data): void
    {
        $fields = [
            'sender_name',
            'sender_email',
            'smtp_host',
            'smtp_port',
            'smtp_username',
            'smtp_password',
            'smtp_encryption',
            'is_enabled',
        ];

        foreach ($fields as $field) {
            if (array_key_exists($field, $data)) {
                $value = $data[$field];
                if (is_string($value)) {
                    $value = trim($value);
                    $value = $value !== '' ? $value : null;
                }
                $settings->{$field} = $value;
            }
        }

        $settings->save();
    }

    private function format(InstitutionEmailSetting $settings): array
    {
        return [
            'sender_name' => $settings->sender_name,
            'sender_email' => $settings->sender_email,
            'smtp_host' => $settings->smtp_host,
            'smtp_port' => $settings->smtp_port,
            'smtp_username_set' => (bool) $settings->smtp_username,
            'smtp_password_set' => (bool) $settings->smtp_password,
            'smtp_username_hint' => $this->maskKey($settings->smtp_username),
            'smtp_password_hint' => $this->maskKey($settings->smtp_password),
            'smtp_encryption' => $settings->smtp_encryption,
            'is_enabled' => (bool) $settings->is_enabled,
        ];
    }

    private function maskKey(?string $value): ?string
    {
        if (!$value) {
            return null;
        }
        $len = strlen($value);
        if ($len <= 6) {
            return str_repeat('•', $len);
        }
        return substr($value, 0, 3) . str_repeat('•', $len - 6) . substr($value, -3);
    }
}
