(define-constant contract-owner tx-sender)
(define-data-var paused bool false)
(define-data-var subsidy-amount uint u0)
(define-data-var cooldown uint u144)
(define-map last-claim { user: principal } { height: uint })
(define-map user-cap { user: principal } { cap: uint })
(define-map user-claimed { user: principal } { total: uint })

(define-public (set-subsidy-amount (amount uint))
  (begin
    (asserts! (is-eq contract-owner tx-sender) (err u100))
    (var-set subsidy-amount amount)
    (ok amount)))

(define-public (set-cooldown (blocks uint))
  (begin
    (asserts! (is-eq contract-owner tx-sender) (err u101))
    (var-set cooldown blocks)
    (ok blocks)))

(define-public (set-paused (value bool))
  (begin
    (asserts! (is-eq contract-owner tx-sender) (err u102))
    (var-set paused value)
    (ok value)))

(define-public (set-user-cap (user principal) (cap uint))
  (begin
    (asserts! (is-eq contract-owner tx-sender) (err u110))
    (map-set user-cap { user: user } { cap: cap })
    (ok cap)))

(define-public (deposit (amount uint))
  (stx-transfer? amount tx-sender (as-contract contract-caller)))

(define-public (withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (as-contract (stx-transfer? amount (as-contract tx-sender) contract-owner))))

(define-read-only (get-config)
  (tuple (amount (var-get subsidy-amount)) (cooldown (var-get cooldown)) (paused (var-get paused))))

(define-read-only (get-user-stats (user principal))
  (let ((claim-entry (map-get? last-claim { user: user }))
        (cap-entry (map-get? user-cap { user: user }))
        (claimed-entry (map-get? user-claimed { user: user }))
        (h (if (is-none claim-entry) u0 (get height (unwrap-panic claim-entry))))
        (c (if (is-none cap-entry) u0 (get cap (unwrap-panic cap-entry))))
        (t (if (is-none claimed-entry) u0 (get total (unwrap-panic claimed-entry)))))
    (tuple (height h) (cap c) (total t))))

(define-read-only (is-eligible (user principal))
  (let ((paused? (var-get paused))
        (amount (var-get subsidy-amount))
        (entry (map-get? last-claim { user: user }))
        (cool (var-get cooldown))
        (now stacks-block-height))
    (if paused?
      false
      (if (is-eq amount u0)
        false
        (if (is-none entry)
          true
          (let ((last (get height (unwrap-panic entry))))
            (>= now (+ last cool))))))))

(define-read-only (get-claim-availability (user principal))
  (let ((paused? (var-get paused))
        (amount (var-get subsidy-amount))
        (entry (map-get? last-claim { user: user }))
        (cool (var-get cooldown))
        (now stacks-block-height)
        (last (if (is-none entry) u0 (get height (unwrap-panic entry))))
        (next (+ last cool))
        (ready (and (not paused?) (not (is-eq amount u0)) (or (is-none entry) (>= now next))))
        (available-at (if ready now next)))
    (tuple (ready ready) (available-at available-at) (amount amount))))

(define-public (claim)
  (let ((p tx-sender)
        (paused? (var-get paused))
        (amount (var-get subsidy-amount))
        (cool (var-get cooldown))
        (now stacks-block-height)
        (entry (map-get? last-claim { user: tx-sender }))
        (cap-entry (map-get? user-cap { user: tx-sender }))
        (claimed-entry (map-get? user-claimed { user: tx-sender }))
        (prev (if (is-none claimed-entry) u0 (get total (unwrap-panic claimed-entry))))
        (new-total (+ prev amount)))
    (begin
      (asserts! (not paused?) (err u104))
      (asserts! (not (is-eq amount u0)) (err u105))
      (asserts! (if (is-none cap-entry) true (<= new-total (get cap (unwrap-panic cap-entry)))) (err u112))
      (if (is-none entry)
        (begin
          (map-set last-claim { user: p } { height: now })
          (map-set user-claimed { user: p } { total: new-total })
          (as-contract (stx-transfer? amount tx-sender p)))
        (let ((last (get height (unwrap-panic entry)))
              (next (+ last cool)))
          (asserts! (>= now next) (err u107))
          (map-set last-claim { user: p } { height: now })
          (map-set user-claimed { user: p } { total: new-total })
          (as-contract (stx-transfer? amount tx-sender p)))))))
