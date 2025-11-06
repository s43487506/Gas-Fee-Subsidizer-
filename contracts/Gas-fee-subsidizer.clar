(define-constant contract-owner tx-sender)
(define-data-var paused bool false)
(define-data-var subsidy-amount uint u0)
(define-data-var cooldown uint u144)
(define-map last-claim { user: principal } { height: uint })

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

(define-public (deposit (amount uint))
  (stx-transfer? amount tx-sender (as-contract contract-caller)))

(define-read-only (get-config)
  (tuple (amount (var-get subsidy-amount)) (cooldown (var-get cooldown)) (paused (var-get paused))))

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

(define-public (claim)
  (let ((p tx-sender)
        (paused? (var-get paused))
        (amount (var-get subsidy-amount))
        (cool (var-get cooldown))
        (now stacks-block-height)
        (entry (map-get? last-claim { user: tx-sender })))
    (begin
      (asserts! (not paused?) (err u104))
      (asserts! (not (is-eq amount u0)) (err u105))
      (if (is-none entry)
        (begin
          (map-set last-claim { user: p } { height: now })
          (as-contract (stx-transfer? amount tx-sender p)))
        (let ((last (get height (unwrap-panic entry)))
              (next (+ last cool)))
          (asserts! (>= now next) (err u107))
          (map-set last-claim { user: p } { height: now })
          (as-contract (stx-transfer? amount tx-sender p)))))))
