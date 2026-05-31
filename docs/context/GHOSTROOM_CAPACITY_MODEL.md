# GHOSTROOM V2.0.1 CAPACITY & COST MODEL

This document estimates the storage growth and operational costs for the GhostRoom durable relay under various user scales.

---

## 1. STORAGE ESTIMATES (Per Message)

| Component | Size (Avg) | Description |
| :--- | :--- | :--- |
| **message_id** | 16 bytes | UUID v7. |
| **recipient_id** | 44 bytes | Base58 Public ID. |
| **envelope (JSONB)** | 1.2 KB | Ciphertext, nonce, wrapped key, signature, and padding. |
| **delivery_state** | 64 bytes | Status, timestamps. |
| **Total per Msg** | **~1.4 KB** | Database row size including overhead. |

---

## 2. GROWTH PROJECTION (PostgreSQL)

**Scenario: 100,000 Active Users**
*   **Assumptions**: 100 messages sent/received per user per day.
*   **Daily Messages**: 10,000,000 messages.
*   **Daily Storage**: 10M * 1.4 KB = **14 GB / day**.
*   **Annual Storage**: **~5.1 TB / year**.
*   **3-Year Storage**: **~15.3 TB**.

**Infrastructure Recommendation**:
*   For 100k users, a managed Postgres instance with high-performance SSD and auto-scaling storage is mandatory.
*   Partitioning the `messages` table by `created_at` (monthly) is recommended to maintain query performance.

---

## 3. MEDIA STORAGE ESTIMATES (Cloudflare R2)

**Scenario: 10% Media Adoption (10k images/day)**
*   **Assumptions**: 500 KB average per compressed/encrypted image.
*   **Daily Storage**: 10,000 * 500 KB = **5 GB / day**.
*   **Annual Storage**: **~1.8 TB / year**.
*   **3-Year Storage**: **~5.4 TB**.

**R2 Costs (Approximate)**:
*   Storage: $0.015 / GB-month.
*   Egress: $0.00 (Zero egress fees is the primary reason for R2 selection).
*   **Annual Storage Cost**: ~$324 / year at 1.8TB.

---

## 4. REDIS CACHE (Memory)

Redis stores the "hot" inbox pointers (last 100 message IDs per active user).

*   **Pointers**: 100,000 users * 100 IDs * 16 bytes = **160 MB**.
*   **Metadata (Challenges/Quotas)**: ~50 MB.
*   **Total RAM Requirement**: **< 1 GB**.
*   **Rationale**: Redis usage remains negligible compared to PostgreSQL, allowing high-performance caching on standard cloud tiers.

---

## 5. SCALABILITY BOTTLENECKS

1.  **Postgres Write IOPS**: At 10M messages/day (~115 msg/sec average, with spikes of 1000+), the primary bottleneck is database write performance.
2.  **Signature Verification**: Ed25519 verification on the relay is fast (~50-100 microseconds), but at 1000+ concurrent connections, CPU utilization must be monitored.
3.  **R2 Transaction Limits**: R2 has high limits, but rapid PUT operations (10k+/day) require monitoring of Class A operations.

---

## 6. DISASTER RECOVERY & BACKUPS

*   **Database**: Full daily backup + WAL archiving for Point-in-Time Recovery (PITR).
*   **Media**: R2 versioning enabled to prevent data loss from accidental deletion.
*   **Recovery Objective**: < 4 hours for full system restoration from total regional failure.
