<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InstitutionEmailSetting extends Model
{
    protected $fillable = [
        'institution_id',
        'sender_name',
        'sender_email',
        'smtp_host',
        'smtp_port',
        'smtp_username',
        'smtp_password',
        'smtp_encryption',
        'is_enabled',
    ];

    protected $casts = [
        'smtp_username' => 'encrypted',
        'smtp_password' => 'encrypted',
        'is_enabled' => 'boolean',
    ];

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }
}
