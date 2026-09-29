<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Receipt</title>
    <style>
      body { font-family: Arial, sans-serif; color: #0f172a; font-size: 12px; }
      h1 { font-size: 18px; margin: 0; }
      .muted { color: #64748b; }
      .header { display: table; width: 100%; border-bottom: 3px solid {{ $primaryColor }}; padding-bottom: 12px; }
      .brand { display: table-cell; vertical-align: middle; }
      .brand img { height: 38px; }
      .brand-title { font-size: 20px; font-weight: 700; color: {{ $primaryColor }}; }
      .meta { display: table-cell; text-align: right; vertical-align: middle; }
      .card { border: 1px solid #e2e8f0; border-radius: 10px; padding: 16px; margin-top: 16px; }
      .grid { display: table; width: 100%; }
      .row { display: table-row; }
      .cell { display: table-cell; padding: 6px 0; vertical-align: top; }
      .label { width: 40%; color: #64748b; }
      .value { width: 60%; }
      .total { font-size: 16px; font-weight: 700; color: {{ $primaryColor }}; }
      .divider { border-top: 1px solid #e2e8f0; margin: 12px 0; }
      .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; background: #eef2ff; color: {{ $primaryColor }}; font-size: 11px; font-weight: 700; }
    </style>
  </head>
  <body>
    <div class="header">
      <div class="brand">
        @if(!empty($logoUrl))
          <img src="{{ $logoUrl }}" alt="Logo">
        @else
          <div class="brand-title">{{ $appName }}</div>
        @endif
      </div>
      <div class="meta">
        <div class="muted">Receipt</div>
        <div class="muted">Generated {{ $generatedAt->format('Y-m-d H:i') }}</div>
      </div>
    </div>

    <div class="card">
      @php
        $metadata = is_array($transaction->metadata ?? null) ? $transaction->metadata : [];
        $feePercent = $metadata['platform_fee_percent'] ?? null;
        $feeAmount = $metadata['platform_fee_amount'] ?? null;
        $netAmount = $metadata['net_amount'] ?? null;
      @endphp
      <div class="grid">
        <div class="row">
          <div class="cell label">Reference</div>
          <div class="cell value">{{ $transaction->reference }}</div>
        </div>
        <div class="row">
          <div class="cell label">Provider reference</div>
          <div class="cell value">{{ $transaction->provider_reference }}</div>
        </div>
        <div class="row">
          <div class="cell label">Type</div>
          <div class="cell value">{{ ucfirst(str_replace('_', ' ', $transaction->type)) }}</div>
        </div>
        <div class="row">
          <div class="cell label">Provider</div>
          <div class="cell value">{{ ucfirst($transaction->provider) }}</div>
        </div>
        <div class="row">
          <div class="cell label">Status</div>
          <div class="cell value"><span class="badge">{{ ucfirst($transaction->status) }}</span></div>
        </div>
        <div class="row">
          <div class="cell label">Amount</div>
          <div class="cell value total">{{ $transaction->currency }} {{ $transaction->amount }}</div>
        </div>
        @if($feePercent !== null)
          <div class="row">
            <div class="cell label">Platform fee (%)</div>
            <div class="cell value">{{ $feePercent }}</div>
          </div>
        @endif
        @if($feeAmount !== null)
          <div class="row">
            <div class="cell label">Platform fee</div>
            <div class="cell value">{{ $transaction->currency }} {{ $feeAmount }}</div>
          </div>
        @endif
        @if($netAmount !== null)
          <div class="row">
            <div class="cell label">Net amount</div>
            <div class="cell value">{{ $transaction->currency }} {{ $netAmount }}</div>
          </div>
        @endif
        <div class="row">
          <div class="cell label">Paid at</div>
          <div class="cell value">{{ optional($transaction->paid_at)->format('Y-m-d H:i') ?? '-' }}</div>
        </div>
        <div class="row">
          <div class="cell label">Refunded at</div>
          <div class="cell value">{{ optional($transaction->refunded_at)->format('Y-m-d H:i') ?? '-' }}</div>
        </div>
      </div>
      <div class="divider"></div>
      <div class="grid">
        <div class="row">
          <div class="cell label">Name</div>
          <div class="cell value">{{ $transaction->user?->name ?? '-' }}</div>
        </div>
        <div class="row">
          <div class="cell label">Email</div>
          <div class="cell value">{{ $transaction->user?->email ?? '-' }}</div>
        </div>
        <div class="row">
          <div class="cell label">Institution</div>
          <div class="cell value">{{ $transaction->institution?->name ?? '-' }}</div>
        </div>
      </div>
    </div>
  </body>
</html>
