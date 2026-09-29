<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Reset password</title>
    <style>
      :root {
        --bg: #f5f7fb;
        --card: #ffffff;
        --text: #0f172a;
        --muted: #64748b;
        --primary: #0f766e;
        --danger: #b91c1c;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        background: var(--bg);
        color: var(--text);
      }
      .wrap {
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
      }
      .card {
        width: 100%;
        max-width: 520px;
        background: var(--card);
        border-radius: 18px;
        padding: 28px;
        box-shadow: 0 20px 60px rgba(15, 23, 42, 0.08);
      }
      h1 {
        margin: 0 0 8px;
        font-size: 24px;
      }
      p { color: var(--muted); margin: 0 0 16px; }
      label { font-size: 12px; color: var(--muted); display: block; margin-bottom: 6px; }
      input {
        width: 100%;
        padding: 12px 14px;
        border-radius: 10px;
        border: 1px solid #e2e8f0;
        margin-bottom: 14px;
        font-size: 14px;
      }
      .btn {
        width: 100%;
        padding: 12px 18px;
        border-radius: 12px;
        border: none;
        background: var(--primary);
        color: #fff;
        font-weight: 600;
        cursor: pointer;
      }
      .error {
        background: #fee2e2;
        color: var(--danger);
        padding: 10px 12px;
        border-radius: 10px;
        margin-bottom: 14px;
        font-size: 13px;
      }
      .footer {
        margin-top: 18px;
        font-size: 12px;
        color: var(--muted);
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <h1>Reset your password</h1>
        <p>Choose a new password for your account.</p>
        @if (!empty($error))
          <div class="error">{{ $error }}</div>
        @endif
        <form method="POST" action="{{ route('password.update') }}">
          @csrf
          <input type="hidden" name="token" value="{{ $token }}" />
          <label>Email</label>
          <input type="email" name="email" value="{{ $email ?? '' }}" required />
          <label>New password</label>
          <input type="password" name="password" required minlength="8" />
          <label>Confirm password</label>
          <input type="password" name="password_confirmation" required minlength="8" />
          <button class="btn" type="submit">Reset password</button>
        </form>
        <div class="footer">If you did not request this, you can ignore this page.</div>
      </div>
    </div>
  </body>
</html>
