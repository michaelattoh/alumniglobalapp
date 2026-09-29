<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;

class AuditLog extends Model
{
    protected $fillable = [
        'actor_id',
        'action',
        'entity_type',
        'entity_id',
        'metadata',
        'ip',
        'user_agent',
    ];

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
        ];
    }

    public function actor()
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    public static function record(?User $actor, string $action, ?string $entityType = null, ?int $entityId = null, array $metadata = [], ?Request $request = null): self
    {
        $req = $request ?: request();

        return self::create([
            'actor_id' => $actor?->id,
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'metadata' => $metadata,
            'ip' => $req?->ip(),
            'user_agent' => $req?->userAgent(),
        ]);
    }
}
