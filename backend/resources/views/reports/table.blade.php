<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{{ $title }}</title>
    <style>
      body { font-family: Arial, sans-serif; color: #0f172a; font-size: 11px; }
      h1 { font-size: 16px; margin: 0 0 6px; }
      .muted { color: #64748b; }
      table { width: 100%; border-collapse: collapse; margin-top: 12px; }
      th, td { border: 1px solid #e2e8f0; padding: 6px 8px; text-align: left; }
      th { background: #f8fafc; font-weight: 700; }
    </style>
  </head>
  <body>
    <h1>{{ $title }}</h1>
    <div class="muted">Generated {{ $generatedAt }}</div>
    @if(!empty($summary))
      <h2 style="font-size:14px;margin:16px 0 6px;">Summary</h2>
      <table>
        <thead>
          <tr>
            <th></th>
            <th>Pending</th>
            <th>Resolved</th>
            <th>Dismissed</th>
            <th>Avg Resolution</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Post reports</td>
            <td>{{ $summary['posts']['pending'] ?? 0 }}</td>
            <td>{{ $summary['posts']['resolved'] ?? 0 }}</td>
            <td>{{ $summary['posts']['dismissed'] ?? 0 }}</td>
            <td>{{ isset($summary['resolution_seconds']['posts']) ? round(($summary['resolution_seconds']['posts'] ?? 0) / 60) : 0 }} min</td>
          </tr>
          <tr>
            <td>User reports</td>
            <td>{{ $summary['users']['pending'] ?? 0 }}</td>
            <td>{{ $summary['users']['resolved'] ?? 0 }}</td>
            <td>{{ $summary['users']['dismissed'] ?? 0 }}</td>
            <td>{{ isset($summary['resolution_seconds']['users']) ? round(($summary['resolution_seconds']['users'] ?? 0) / 60) : 0 }} min</td>
          </tr>
        </tbody>
      </table>

      <h2 style="font-size:14px;margin:16px 0 6px;">Top reasons</h2>
      <table>
        <thead>
          <tr>
            <th>Type</th>
            <th>Reason</th>
            <th>Count</th>
          </tr>
        </thead>
        <tbody>
          @foreach(($summary['reasons']['posts'] ?? []) as $row)
            <tr>
              <td>Post</td>
              <td>{{ $row['reason'] }}</td>
              <td>{{ $row['count'] }}</td>
            </tr>
          @endforeach
          @foreach(($summary['reasons']['users'] ?? []) as $row)
            <tr>
              <td>User</td>
              <td>{{ $row['reason'] }}</td>
              <td>{{ $row['count'] }}</td>
            </tr>
          @endforeach
          @if(empty($summary['reasons']['posts']) && empty($summary['reasons']['users']))
            <tr><td colspan="3">No reasons available.</td></tr>
          @endif
        </tbody>
      </table>

      <h2 style="font-size:14px;margin:16px 0 6px;">SLA buckets</h2>
      <table>
        <thead>
          <tr>
            <th>Type</th>
            <th>&lt; 24h</th>
            <th>24-48h</th>
            <th>48h+</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Post</td>
            <td>{{ $summary['sla']['posts']['under_24h'] ?? 0 }}</td>
            <td>{{ $summary['sla']['posts']['under_48h'] ?? 0 }}</td>
            <td>{{ $summary['sla']['posts']['over_48h'] ?? 0 }}</td>
          </tr>
          <tr>
            <td>User</td>
            <td>{{ $summary['sla']['users']['under_24h'] ?? 0 }}</td>
            <td>{{ $summary['sla']['users']['under_48h'] ?? 0 }}</td>
            <td>{{ $summary['sla']['users']['over_48h'] ?? 0 }}</td>
          </tr>
        </tbody>
      </table>

      <h2 style="font-size:14px;margin:16px 0 6px;">Top institutions</h2>
      <table>
        <thead>
          <tr>
            <th>Type</th>
            <th>Institution</th>
            <th>Count</th>
          </tr>
        </thead>
        <tbody>
          @foreach(($summary['institutions']['posts'] ?? []) as $row)
            <tr>
              <td>Post</td>
              <td>{{ $row['name'] }}</td>
              <td>{{ $row['count'] }}</td>
            </tr>
          @endforeach
          @foreach(($summary['institutions']['users'] ?? []) as $row)
            <tr>
              <td>User</td>
              <td>{{ $row['name'] }}</td>
              <td>{{ $row['count'] }}</td>
            </tr>
          @endforeach
          @if(empty($summary['institutions']['posts']) && empty($summary['institutions']['users']))
            <tr><td colspan="3">No institution data.</td></tr>
          @endif
        </tbody>
      </table>
    @endif

    <h2 style="font-size:14px;margin:16px 0 6px;">Report details</h2>
    <table>
      <thead>
        <tr>
          <th>Type</th>
          <th>Reporter</th>
          <th>Subject</th>
          <th>Reason</th>
          <th>Status</th>
          <th>Created</th>
        </tr>
      </thead>
      <tbody>
        @forelse ($rows as $row)
          <tr>
            <td>{{ $row['type'] }}</td>
            <td>{{ $row['reporter'] }}</td>
            <td>{{ $row['subject'] }}</td>
            <td>{{ $row['reason'] }}</td>
            <td>{{ $row['status'] }}</td>
            <td>{{ $row['created_at'] }}</td>
          </tr>
        @empty
          <tr>
            <td colspan="6">No reports found.</td>
          </tr>
        @endforelse
      </tbody>
    </table>
  </body>
</html>
