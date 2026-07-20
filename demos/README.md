# Demo captures

## Latest (symlinks)

- Recording: [`recordings/latest.mp4`](recordings/latest.mp4)
- Screenshots: [`recordings/latest-screenshots/`](recordings/latest-screenshots)
- Working copy of the last run: [`walletops-demo-walkthrough.mp4`](walletops-demo-walkthrough.mp4) + [`screenshots/`](screenshots)

## Walkthrough steps

1. Login  
2. Events  
3. Rules list (alert rules matched by the worker)  
4. Rule detail / edit sheet  
5. Events → Run live demo (confirm)  
6. PENDING → PROCESSING → PROCESSED  
7. Event detail + matched rule in pipeline  
8. Rules again after the demo  

## Re-record

```bash
docker compose up --build -d   # DEMO_PROCESS_DELAY_MS=5000
./scripts/record_demo_walkthrough.sh
```

Requires a booted iOS Simulator and API on `http://127.0.0.1:8080`.
Each run also archives a timestamped copy under `recordings/`.
