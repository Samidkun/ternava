<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Retention windows (days)
    |--------------------------------------------------------------------------
    |
    | Bounded operational retention from docs/operations-security.md. Business
    | records, ledger entries, snapshots and the audit trail are kept for 730
    | days; only derived/ephemeral data expires earlier. Deduplication receipts
    | are intentionally NOT listed here: they are retained while the farm is
    | active so an old queued intent can still be replayed without re-applying
    | its business effect (invariant in App\Support\MutationExecutor).
    |
    */
    'retention' => [
        'business_days' => 730,      // daily records, ledger, revisions, audit
        'photo_days' => 180,         // attachment bytes + attachment rows
        'inbox_days' => 90,          // inbox items
        'delta_days' => 30,          // sync_changes replay log
        'log_days' => 14,            // redacted request logs
        'backup_days' => 30,         // documentacion only; enforced by ops/backup.sh (T43)
    ],

    /*
    |--------------------------------------------------------------------------
    | Rate limits (requests per minute)
    |--------------------------------------------------------------------------
    */
    'limits' => [
        'auth_per_minute' => 120,
        'upload_per_minute' => 10,
        'export_per_minute' => 3,
        'json_body_bytes' => 65536, // 64 KiB
    ],
];
