<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class PaymentTransactionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $receiptUrl = $this->receipt_url;
        if (is_string($receiptUrl) && preg_match('/receipt(s)?\\.example/i', $receiptUrl)) {
            $receiptUrl = null;
        }
        if (!$receiptUrl && $this->provider_reference) {
            $base = 'receipts/' . $this->provider_reference;
            $disk = Storage::disk('public');
            $extensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];
            foreach ($extensions as $ext) {
                $path = $base . '.' . $ext;
                if ($disk->exists($path)) {
                    $receiptUrl = $disk->url($path);
                    break;
                }
            }
        }
        return [
            'id' => $this->id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'type' => $this->type,
            'provider' => $this->provider,
            'status' => $this->status,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'reference' => $this->reference,
            'provider_reference' => $this->provider_reference,
            'receipt_url' => $receiptUrl,
            'metadata' => $this->metadata,
            'paid_at' => optional($this->paid_at)?->toIso8601String(),
            'refunded_at' => optional($this->refunded_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
