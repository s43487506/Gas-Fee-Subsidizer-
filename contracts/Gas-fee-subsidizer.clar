(define-constant contract-owner tx-sender)

(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-user-not-registered (err u102))
(define-constant err-subsidy-limit-exceeded (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-contract-paused (err u105))
(define-constant err-user-already-registered (err u106))
(define-constant err-insufficient-subsidy-pool (err u107))
(define-constant err-insufficient-credits (err u108))
(define-constant err-transfer-failed (err u109))

(define-data-var contract-paused bool false)
(define-data-var total-subsidized uint u0)
(define-data-var subsidy-pool uint u0)
(define-data-var default-daily-limit uint u1000000)
(define-data-var max-single-subsidy uint u500000)
(define-data-var total-credits-minted uint u0)
(define-data-var total-credits-redeemed uint u0)

(define-map user-profiles
  { user: principal }
  {
    registered: bool,
    daily-limit: uint,
    daily-used: uint,
    total-subsidized: uint,
    last-reset-block: uint
  }
)

(define-map subsidization-history
  { tx-id: uint }
  {
    user: principal,
    amount: uint,
    stacks-block-height: uint,
    subsidizer: principal
  }
)

(define-map subsidy-credits
  { holder: principal }
  { balance: uint }
)

(define-map credit-transactions
  { credit-tx-id: uint }
  {
    from: principal,
    to: principal,
    amount: uint,
    tx-type: (string-ascii 20),
    stacks-block-height: uint
  }
)

(define-data-var next-tx-id uint u1)
(define-data-var next-credit-tx-id uint u1)

(define-read-only (get-contract-info)
  {
    owner: contract-owner,
    paused: (var-get contract-paused),
    subsidy-pool: (var-get subsidy-pool),
    total-subsidized: (var-get total-subsidized),
    default-daily-limit: (var-get default-daily-limit),
    max-single-subsidy: (var-get max-single-subsidy)
  }
)

(define-read-only (get-user-profile (user principal))
  (match (map-get? user-profiles { user: user })
    profile (some profile)
    none
  )
)

(define-read-only (get-subsidization-record (tx-id uint))
  (map-get? subsidization-history { tx-id: tx-id })
)

(define-read-only (is-user-registered (user principal))
  (match (map-get? user-profiles { user: user })
    profile (get registered profile)
    false
  )
)

(define-read-only (get-available-daily-subsidy (user principal))
  (match (map-get? user-profiles { user: user })
    profile 
      (let ((blocks-since-reset (- stacks-block-height (get last-reset-block profile))))
        (if (>= blocks-since-reset u144)
          (get daily-limit profile)
          (- (get daily-limit profile) (get daily-used profile))
        )
      )
    u0
  )
)

(define-read-only (calculate-subsidy-amount (gas-cost uint))
  (if (<= gas-cost (var-get max-single-subsidy))
    gas-cost
    (var-get max-single-subsidy)
  )
)

(define-private (reset-daily-usage-if-needed (user principal))
  (match (map-get? user-profiles { user: user })
    profile
      (let ((blocks-since-reset (- stacks-block-height (get last-reset-block profile))))
        (if (>= blocks-since-reset u144)
          (map-set user-profiles
            { user: user }
            (merge profile { daily-used: u0, last-reset-block: stacks-block-height })
          )
          true
        )
      )
    false
  )
)

(define-public (deposit-subsidy-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set subsidy-pool (+ (var-get subsidy-pool) amount))
    (ok amount)
  )
)

(define-public (withdraw-subsidy-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get subsidy-pool)) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set subsidy-pool (- (var-get subsidy-pool) amount))
    (ok amount)
  )
)

(define-public (register-user (user principal) (daily-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-user-registered user)) err-user-already-registered)
    (asserts! (> daily-limit u0) err-invalid-amount)
    (map-set user-profiles
      { user: user }
      {
        registered: true,
        daily-limit: daily-limit,
        daily-used: u0,
        total-subsidized: u0,
        last-reset-block: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (register-user-default (user principal))
  (register-user user (var-get default-daily-limit))
)

(define-public (update-user-daily-limit (user principal) (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-user-registered user) err-user-not-registered)
    (asserts! (> new-limit u0) err-invalid-amount)
    (match (map-get? user-profiles { user: user })
      profile
        (begin
          (map-set user-profiles
            { user: user }
            (merge profile { daily-limit: new-limit })
          )
          (ok new-limit)
        )
      err-user-not-registered
    )
  )
)

(define-public (subsidize-gas-fee (user principal) (gas-cost uint))
  (let (
    (subsidy-amount (calculate-subsidy-amount gas-cost))
    (tx-id (var-get next-tx-id))
  )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-user-registered user) err-user-not-registered)
    (asserts! (> gas-cost u0) err-invalid-amount)
    (asserts! (<= subsidy-amount (var-get subsidy-pool)) err-insufficient-subsidy-pool)
    
    (reset-daily-usage-if-needed user)
    (asserts! (<= subsidy-amount (get-available-daily-subsidy user)) err-subsidy-limit-exceeded)
    
    (try! (as-contract (stx-transfer? subsidy-amount tx-sender user)))
    
    (match (map-get? user-profiles { user: user })
      profile
        (map-set user-profiles
          { user: user }
          (merge profile {
            daily-used: (+ (get daily-used profile) subsidy-amount),
            total-subsidized: (+ (get total-subsidized profile) subsidy-amount)
          })
        )
      false
    )
    
    (map-set subsidization-history
      { tx-id: tx-id }
      {
        user: user,
        amount: subsidy-amount,
        stacks-block-height: stacks-block-height,
        subsidizer: tx-sender
      }
    )
    
    (var-set next-tx-id (+ tx-id u1))
    (var-set subsidy-pool (- (var-get subsidy-pool) subsidy-amount))
    (var-set total-subsidized (+ (var-get total-subsidized) subsidy-amount))
    
    (ok subsidy-amount)
  )
)

(define-public (bulk-subsidize (users (list 10 principal)) (gas-costs (list 10 uint)))
  (begin
    (asserts! (is-eq (len users) (len gas-costs)) err-invalid-amount)
    (let ((paired-data (zip users gas-costs)))
      (fold subsidize-user-fee paired-data (ok (list)))
    )
  )
)

(define-private (subsidize-user-fee (user-cost { user: principal, gas-cost: uint }) (prev-result (response (list 10 uint) uint)))
  (match prev-result
    ok-list
      (match (subsidize-gas-fee (get user user-cost) (get gas-cost user-cost))
        ok-amount (ok (unwrap-panic (as-max-len? (append ok-list ok-amount) u10)))
        err-val (err err-val)
      )
    err-val (err err-val)
  )
)

(define-private (zip (list-a (list 10 principal)) (list-b (list 10 uint)))
  (map make-pair list-a list-b)
)

(define-private (make-pair (a principal) (b uint))
  { user: a, gas-cost: b }
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (emergency-unpause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (set-default-daily-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-limit u0) err-invalid-amount)
    (var-set default-daily-limit new-limit)
    (ok new-limit)
  )
)

(define-public (set-max-single-subsidy (new-max uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-max u0) err-invalid-amount)
    (var-set max-single-subsidy new-max)
    (ok new-max)
  )
)

(define-read-only (get-subsidy-stats)
  {
    total-subsidized: (var-get total-subsidized),
    current-pool: (var-get subsidy-pool),
    total-transactions: (- (var-get next-tx-id) u1)
  }
)

(define-public (deregister-user (user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-user-registered user) err-user-not-registered)
    (map-delete user-profiles { user: user })
    (ok true)
  )
)

(define-read-only (get-credit-balance (holder principal))
  (default-to u0 (get balance (map-get? subsidy-credits { holder: holder })))
)

(define-read-only (get-credit-transaction (credit-tx-id uint))
  (map-get? credit-transactions { credit-tx-id: credit-tx-id })
)

(define-read-only (get-credits-info)
  {
    total-minted: (var-get total-credits-minted),
    total-redeemed: (var-get total-credits-redeemed),
    circulating: (- (var-get total-credits-minted) (var-get total-credits-redeemed))
  }
)

(define-private (record-credit-transaction (from principal) (to principal) (amount uint) (tx-type (string-ascii 20)))
  (let ((credit-tx-id (var-get next-credit-tx-id)))
    (map-set credit-transactions
      { credit-tx-id: credit-tx-id }
      {
        from: from,
        to: to,
        amount: amount,
        tx-type: tx-type,
        stacks-block-height: stacks-block-height
      }
    )
    (var-set next-credit-tx-id (+ credit-tx-id u1))
    credit-tx-id
  )
)

(define-public (mint-credits (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (let (
      (current-balance (get-credit-balance recipient))
      (new-balance (+ current-balance amount))
    )
      (map-set subsidy-credits
        { holder: recipient }
        { balance: new-balance }
      )
      (var-set total-credits-minted (+ (var-get total-credits-minted) amount))
      (record-credit-transaction contract-owner recipient amount "mint")
      (ok new-balance)
    )
  )
)

(define-public (burn-credits (holder principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (let (
      (current-balance (get-credit-balance holder))
    )
      (asserts! (>= current-balance amount) err-insufficient-credits)
      (map-set subsidy-credits
        { holder: holder }
        { balance: (- current-balance amount) }
      )
      (var-set total-credits-redeemed (+ (var-get total-credits-redeemed) amount))
      (record-credit-transaction holder contract-owner amount "burn")
      (ok (- current-balance amount))
    )
  )
)

(define-public (transfer-credits (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (let (
      (sender-balance (get-credit-balance tx-sender))
      (recipient-balance (get-credit-balance recipient))
    )
      (asserts! (>= sender-balance amount) err-insufficient-credits)
      (map-set subsidy-credits
        { holder: tx-sender }
        { balance: (- sender-balance amount) }
      )
      (map-set subsidy-credits
        { holder: recipient }
        { balance: (+ recipient-balance amount) }
      )
      (record-credit-transaction tx-sender recipient amount "transfer")
      (ok amount)
    )
  )
)

(define-public (redeem-credits-for-subsidy (amount uint))
  (begin
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (let (
      (user-credits (get-credit-balance tx-sender))
      (subsidy-amount (calculate-subsidy-amount amount))
    )
      (asserts! (>= user-credits subsidy-amount) err-insufficient-credits)
      (asserts! (<= subsidy-amount (var-get subsidy-pool)) err-insufficient-subsidy-pool)
      
      (map-set subsidy-credits
        { holder: tx-sender }
        { balance: (- user-credits subsidy-amount) }
      )
      
      (try! (as-contract (stx-transfer? subsidy-amount tx-sender tx-sender)))
      
      (var-set total-credits-redeemed (+ (var-get total-credits-redeemed) subsidy-amount))
      (var-set subsidy-pool (- (var-get subsidy-pool) subsidy-amount))
      (var-set total-subsidized (+ (var-get total-subsidized) subsidy-amount))
      
      (record-credit-transaction tx-sender contract-owner subsidy-amount "redeem")
      (ok subsidy-amount)
    )
  )
)

(define-public (batch-mint-credits (recipients (list 20 principal)) (amounts (list 20 uint)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (len recipients) (len amounts)) err-invalid-amount)
    (let ((paired-data (zip-credits recipients amounts)))
      (fold mint-credit-pair paired-data (ok (list)))
    )
  )
)

(define-private (mint-credit-pair (pair { recipient: principal, amount: uint }) (prev-result (response (list 20 uint) uint)))
  (match prev-result
    ok-list
      (match (mint-credits (get recipient pair) (get amount pair))
        ok-balance (ok (unwrap-panic (as-max-len? (append ok-list ok-balance) u20)))
        err-val (err err-val)
      )
    err-val (err err-val)
  )
)

(define-private (zip-credits (list-a (list 20 principal)) (list-b (list 20 uint)))
  (map make-credit-pair list-a list-b)
)

(define-private (make-credit-pair (a principal) (b uint))
  { recipient: a, amount: b }
)
