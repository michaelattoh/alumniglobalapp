<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Password updated</title>
    <style>
      :root {
        --bg: #f5f7fb;
        --card: #ffffff;
        --text: #0f172a;
        --muted: #64748b;
        --primary: #0f766e;
        --accent: #e2f3f1;
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
        text-align: center;
      }
      .badge {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        background: var(--accent);
        color: var(--primary);
        border-radius: 999px;
        font-weight: 600;
        font-size: 12px;
      }
      h1 { margin: 16px 0 8px; font-size: 24px; }
      p { color: var(--muted); margin: 0; }
      .cta {
        margin-top: 20px;
        display: inline-block;
        text-decoration: none;
        background: var(--primary);
        color: #fff;
        padding: 12px 18px;
        border-radius: 12px;
        font-weight: 600;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <div class="badge">Alumni Global Network</div>
        <h1>Password updated</h1>
        <p>Your password has been reset. You can now return to the app and sign in.</p>
        <a class="cta" href="https://alumniglobalnetwork.com">Back to Alumni Global</a>
      </div>
    </div>
  </body>
</html>
