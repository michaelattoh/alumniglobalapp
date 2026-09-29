<?php

namespace App\Services;

use App\Models\PaymentTransaction;
use App\Models\SystemSetting;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Support\Facades\Storage;

class ReceiptService
{
    public function generate(PaymentTransaction $transaction): ?string
    {
        if (!$transaction->provider_reference) {
            return null;
        }

        $path = 'receipts/' . $transaction->provider_reference . '.pdf';
        $disk = Storage::disk('public');

        if ($disk->exists($path)) {
            return $disk->url($path);
        }

        $logoUrl = SystemSetting::query()->where('key', 'logo_url')->value('value');
        $primaryColor = SystemSetting::query()->where('key', 'primary_color')->value('value');
        $appName = SystemSetting::query()->where('key', 'app_name')->value('value');
        $html = view('receipts.transaction', [
            'transaction' => $transaction->loadMissing(['user', 'institution']),
            'appName' => is_string($appName) && $appName !== '' ? $appName : config('app.name'),
            'generatedAt' => now(),
            'logoUrl' => is_string($logoUrl) ? $logoUrl : null,
            'primaryColor' => is_string($primaryColor) && $primaryColor !== '' ? $primaryColor : '#0f172a',
        ])->render();

        $options = new Options();
        $options->set('isRemoteEnabled', true);
        $options->set('isHtml5ParserEnabled', true);
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html);
        $dompdf->setPaper('a4');
        $dompdf->render();

        $disk->put($path, $dompdf->output());

        return $disk->url($path);
    }
}
