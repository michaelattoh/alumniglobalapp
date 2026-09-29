<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{{ $title }}</title>
    <style>
      body { font-family: Arial, sans-serif; color: #0f172a; font-size: 11px; }
      h1 { font-size: 16px; margin: 0 0 6px; }
      h2 { font-size: 14px; margin: 16px 0 6px; }
      .muted { color: #64748b; }
      table { width: 100%; border-collapse: collapse; margin-top: 12px; }
      th, td { border: 1px solid #e2e8f0; padding: 6px 8px; text-align: left; }
      th { background: #f8fafc; font-weight: 700; }
      .summary-grid { width: 100%; margin-top: 12px; border-collapse: collapse; }
      .summary-grid td { border: 1px solid #e2e8f0; padding: 8px; width: 20%; }
      .summary-label { display: block; font-size: 10px; color: #64748b; text-transform: uppercase; margin-bottom: 4px; }
      .summary-value { font-size: 15px; font-weight: 700; }
      .right { text-align: right; }
    </style>
  </head>
  <body>
    <h1>{{ $title }}</h1>
    <div class="muted">Generated {{ $generatedAt }}</div>
    <div class="muted">Period {{ $period['from'] ?? '—' }} to {{ $period['to'] ?? '—' }}</div>

    @if(!empty($summary))
      <table class="summary-grid">
        <tr>
          @foreach($summary as $item)
            <td>
              <span class="summary-label">{{ $item['label'] }}</span>
              <span class="summary-value">{{ $item['value'] }}</span>
            </td>
          @endforeach
        </tr>
      </table>
    @endif

    <h2>School details</h2>
    <table>
      <thead>
        <tr>
          <th>School</th>
          <th>School ID</th>
          <th>Status</th>
          <th>Location</th>
          <th class="right">Users</th>
          <th class="right">New users</th>
          <th class="right">Admins</th>
          <th class="right">Year groups</th>
          <th class="right">Posts</th>
          <th class="right">Events</th>
          <th class="right">Attendance</th>
          <th class="right">Donations</th>
          <th class="right">Pending verifications</th>
          <th>Inactive</th>
        </tr>
      </thead>
      <tbody>
        @forelse($schools as $school)
          <tr>
            <td>{{ $school['name'] ?? '-' }}</td>
            <td>{{ $school['school_id'] ?? '-' }}</td>
            <td>{{ $school['status'] ?? '-' }}</td>
            <td>{{ $school['location'] ?? '-' }}</td>
            <td class="right">{{ $school['users_count'] ?? 0 }}</td>
            <td class="right">{{ $school['new_users_count'] ?? 0 }}</td>
            <td class="right">{{ $school['admins_count'] ?? 0 }}</td>
            <td class="right">{{ $school['year_groups_count'] ?? 0 }}</td>
            <td class="right">{{ $school['posts_count'] ?? 0 }}</td>
            <td class="right">{{ $school['events_count'] ?? 0 }}</td>
            <td class="right">{{ $school['event_attendance_total'] ?? 0 }}</td>
            <td class="right">{{ number_format((float) ($school['donations_total'] ?? 0), 2) }}</td>
            <td class="right">{{ $school['pending_verifications_count'] ?? 0 }}</td>
            <td>
              @if(($school['inactive_days'] ?? null) === null)
                No activity yet
              @else
                {{ $school['inactive_days'] }} days
              @endif
            </td>
          </tr>
        @empty
          <tr>
            <td colspan="14">No schools found.</td>
          </tr>
        @endforelse
      </tbody>
    </table>
  </body>
</html>
