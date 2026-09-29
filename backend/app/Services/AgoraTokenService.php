<?php

namespace App\Services;

use CyberDeep\LaravelAgoraTokenGenerator\Services\Agora;

class AgoraTokenService
{
    public function buildRtcToken(string $channel, int $uid, int $expireSeconds = 3600): ?string
    {
        $appId = config('services.agora.app_id');
        $appCertificate = config('services.agora.app_certificate');

        if (!$appId || !$appCertificate) {
            return null;
        }
        if (!class_exists(Agora::class)) {
            return null;
        }

        // The package reads AGORA_* values from env and uses Agora's token builder underneath.
        return Agora::make((string) $uid)
            ->channel($channel)
            ->uId((string) $uid)
            ->join(false)
            ->audioOnly(false)
            ->token();
    }
}
