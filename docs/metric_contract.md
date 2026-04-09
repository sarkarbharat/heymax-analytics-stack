# Growth Accounting Metric Contract

## Grain and Definitions

- **Active user (period P):** a distinct `user_id` with at least one event in period `P`.
- **Prior period:** the immediate previous period at the same grain.
  - Daily -> previous day
  - Weekly -> previous ISO week
  - Monthly -> previous calendar month

## Set Notation

- `A(P)`: active users in current period `P`
- `A(P-1)`: active users in prior period
- `H(P-2...)`: historical users active before prior period

## Required Metrics

- **New Users**
  - Users active in `P` whose first-ever active period equals `P`.
  - Formula: `new = A(P) where first_active_period = P`
- **Retained Users**
  - Users active in both current and prior period.
  - Formula: `retained = A(P) ∩ A(P-1)`
- **Resurrected Users**
  - Users active in `P`, not active in `P-1`, and active at least once before `P-1`.
  - Formula: `resurrected = (A(P) - A(P-1)) ∩ H(P-2...)`
- **Churned Users**
  - Users active in `P-1` but not active in `P`.
  - Formula: `churned = A(P-1) - A(P)`

## Output Contract

- Metrics are produced for `daily`, `weekly`, and `monthly` grains.
- Output columns:
  - `period_grain`
  - `period_start`
  - `new_users`
  - `retained_users`
  - `resurrected_users`
  - `churned_users`
  - `active_users`

## Edge-Case Rules

- First observed period has no prior period:
  - `retained_users = 0`
  - `resurrected_users = 0`
  - `churned_users = 0`
- Multiple events by one user in a period count as one active user.
- All period bucketing uses UTC for deterministic comparisons.
