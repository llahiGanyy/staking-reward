;; -------------------------------------------------------------
;; Contract: staking-reward.clar
;; Description: Simple STX staking and reward distribution vault
;; -------------------------------------------------------------

(define-constant ERR-ZERO-AMOUNT u100)
(define-constant ERR-NO-STAKE u101)
(define-constant ERR-NOT-OWNER u102)
(define-constant ERR-NO-REWARD-FUNDS u103)

;; -----------------------------
;; Data Variables and Structures
;; -----------------------------

;; Contract owner (admin)
(define-data-var owner (optional principal) none)

;; Total STX staked across all users
(define-data-var total-staked uint u0)

;; Reward pool funded by owner
(define-data-var reward-pool uint u0)

;; Reward rate (STX per block per 1 staked STX, scaled by 1/1000)
;; e.g. u5 = 0.5% reward per block (for demo)
(define-data-var reward-rate uint u5)

;; User staking info
(define-map stakers
  { user: principal }
  { amount: uint, last-block: uint, unclaimed: uint })

;; -----------------------------
;; Initialization
;; -----------------------------

(define-public (initialize (admin principal))
  (let ((owner-val (var-get owner)))
    (if (is-none owner-val)
      (begin
        (var-set owner (some admin))
        (ok true)
      )
      (err ERR-NOT-OWNER)
    )
  )
)

;; -----------------------------
;; Owner-only Functions
;; -----------------------------

(define-public (fund-rewards (amount uint))
  (let ((caller tx-sender))
    (if (> amount u0)
      (match (var-get owner)
        some-owner
          (if (is-eq caller some-owner)
              (begin
                (try! (stx-transfer? amount caller (as-contract tx-sender)))
                (var-set reward-pool (+ (var-get reward-pool) amount))
                (ok (var-get reward-pool))
              )
              (err ERR-NOT-OWNER)
          )
        (err ERR-NOT-OWNER)
      )
      (err ERR-ZERO-AMOUNT)
    )
  )
)

(define-public (set-reward-rate (new-rate uint))
  (match (var-get owner)
    some-owner
      (if (is-eq tx-sender some-owner)
          (if (>= new-rate u0)
            (begin
              (var-set reward-rate new-rate)
              (ok new-rate)
            )
            (err ERR-ZERO-AMOUNT)
          )
          (err ERR-NOT-OWNER)
      )
    (err ERR-NOT-OWNER)
  )
)

;; -----------------------------
;; Stake STX
;; -----------------------------

(define-public (stake (amount uint))
  (let (
        (sender tx-sender)
       )
    (if (<= amount u0)
        (err ERR-ZERO-AMOUNT)
        (let (
              (maybe-stake (map-get? stakers { user: sender }))
              (cur-block burn-block-height)
             )
          (if (is-some maybe-stake)
              ;; Update rewards if user already staked
              (let (
                    (record (unwrap! maybe-stake (err ERR-NO-STAKE)))
                    (old-amount (get amount record))
                    (last-block (get last-block record))
                    (pending (/ (* old-amount (- cur-block last-block) (var-get reward-rate)) u1000))
                    (new-unclaimed (+ (get unclaimed record) pending))
                   )
                (begin
                  (try! (stx-transfer? amount sender (as-contract tx-sender)))
                  (map-set stakers { user: sender }
                           { amount: (+ old-amount amount),
                             last-block: cur-block,
                             unclaimed: new-unclaimed })
                  (var-set total-staked (+ (var-get total-staked) amount))
                  (ok (+ old-amount amount))
                )
              )
              ;; First-time stake
              (begin
                (try! (stx-transfer? amount sender (as-contract tx-sender)))
                (map-set stakers { user: sender } { amount: amount, last-block: cur-block, unclaimed: u0 })
                (var-set total-staked (+ (var-get total-staked) amount))
                (ok amount)
              )
          )
        )
    )
  )
)

;; -----------------------------
;; Claim Rewards
;; -----------------------------

(define-public (claim-rewards)
  (let ((sender tx-sender)
        (cur-block burn-block-height))
    (match (map-get? stakers { user: sender })
      some-stake
        (let (
              (staked (get amount some-stake))
              (last-block (get last-block some-stake))
              (pending (/ (* staked (- cur-block last-block) (var-get reward-rate)) u1000))
              (total-reward (+ (get unclaimed some-stake) pending))
             )
          (if (> total-reward (var-get reward-pool))
              (err ERR-NO-REWARD-FUNDS)
              (begin
                ;; transfer STX reward
                (try! (stx-transfer? total-reward (as-contract tx-sender) sender))
                (var-set reward-pool (- (var-get reward-pool) total-reward))
                ;; update user record
                (map-set stakers { user: sender }
                         { amount: staked, last-block: cur-block, unclaimed: u0 })
                (ok total-reward)
              )
          )
        )
      (err ERR-NO-STAKE)
    )
  )
)

;; -----------------------------
;; Unstake
;; -----------------------------

(define-public (unstake)
  (let ((sender tx-sender)
        (cur-block burn-block-height))
    (match (map-get? stakers { user: sender })
      some-stake
        (let (
              (staked (get amount some-stake))
              (last-block (get last-block some-stake))
              (pending (/ (* staked (- cur-block last-block) (var-get reward-rate)) u1000))
              (total-reward (+ (get unclaimed some-stake) pending))
             )
          (begin
            ;; transfer staked + reward
            (try! (stx-transfer? (+ staked total-reward) (as-contract tx-sender) sender))
            ;; update totals
            (var-set total-staked (- (var-get total-staked) staked))
            (var-set reward-pool (- (var-get reward-pool) total-reward))
            ;; remove staker record
            (map-delete stakers { user: sender })
            (ok (+ staked total-reward))
          )
        )
      (err ERR-NO-STAKE)
    )
  )
)

;; -----------------------------
;; Read-only Helper Functions
;; -----------------------------

(define-read-only (get-staker (user principal))
  (match (map-get? stakers { user: user })
    some-stake (ok some-stake)
    (ok { amount: u0, last-block: u0, unclaimed: u0 })
  )
)

(define-read-only (get-total-staked)
  (ok (var-get total-staked)))

(define-read-only (get-reward-pool)
  (ok (var-get reward-pool)))

(define-read-only (get-reward-rate)
  (ok (var-get reward-rate)))

(define-read-only (get-owner)
  (ok (var-get owner)))
