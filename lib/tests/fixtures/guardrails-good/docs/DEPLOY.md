# Deploy

Traffic goes through Cloudflare, with WAF and DDoS rules on.
Rate limits live in the middleware.
Spend cap is set in the host dashboard, and a budget alert triggers the
kill switch described in the runbook.
