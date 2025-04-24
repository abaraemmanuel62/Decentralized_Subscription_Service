
;; title: Decentralized Subscription Service
;; version:
;; summary:
;; description: A protocol for recurring cryptocurrency payments with adjustable billing cycles

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-subscription (err u102))
(define-constant err-insufficient-balance (err u103)) 
(define-constant err-invalid-period (err u104))
(define-constant err-subscription-expired (err u105))
(define-constant err-subscription-active (err u106))
(define-constant err-invalid-amount (err u107))

;; Data structures
(define-map subscriptions
  { subscription-id: uint }
  {
    provider: principal,
    subscriber: principal,
    amount: uint,
    period: uint,        ;; billing cycle in blocks
    next-billing: uint,  ;; block height for next payment
    auto-renew: bool,
    status: (string-ascii 20),  ;; "active", "cancelled", "expired"
    metadata: (optional (string-utf8 256))
  }
)


(define-map provider-subscriptions
  { provider: principal }
  { subscription-ids: (list 100 uint) }
)

(define-map subscriber-subscriptions
  { subscriber: principal }
  { subscription-ids: (list 100 uint) }
)

;; Provider revenue tracking
(define-map provider-revenue
  { provider: principal }
  { total: uint, pending-withdrawal: uint }
)

;; Counter for subscription IDs
(define-data-var subscription-id-counter uint u0)



;; Create a new subscription
(define-public (create-subscription 
                (provider principal)
                (amount uint)
                (period uint)
                (auto-renew bool)
                (metadata (optional (string-utf8 256))))
  (let
    (
      (next-id (+ (var-get subscription-id-counter) u1))
      (current-block-height block-height)
      (next-billing (+ current-block-height period))
    )
    ;; Validate inputs
    (asserts! (> amount u0) (err-invalid-amount))
    (asserts! (> period u0) (err-invalid-period))
    
    ;; Create subscription
    (map-set subscriptions
      { subscription-id: next-id }
      {
        provider: provider,
        subscriber: tx-sender,
        amount: amount,
        period: period,
        next-billing: next-billing,
        auto-renew: auto-renew,
        status: "active",
        metadata: metadata
      }
    )
    
    ;; Update provider subscriptions list
    (match (map-get? provider-subscriptions { provider: provider })
      existing-data (map-set provider-subscriptions
                      { provider: provider }
                      { subscription-ids: (append (get subscription-ids existing-data) next-id) })
      (map-set provider-subscriptions
        { provider: provider }
        { subscription-ids: (list next-id) })
    )
    
    ;; Update subscriber subscriptions list
    (match (map-get? subscriber-subscriptions { subscriber: tx-sender })
      existing-data (map-set subscriber-subscriptions
                      { subscriber: tx-sender }
                      { subscription-ids: (append (get subscription-ids existing-data) next-id) })
      (map-set subscriber-subscriptions
        { subscriber: tx-sender }
        { subscription-ids: (list next-id) })
    )
  ))

  ;; Make first payment
    (try! (stx-transfer? amount tx-sender provider))
    
    ;; Update provider revenue
    (match (map-get? provider-revenue { provider: provider })
      existing-revenue (map-set provider-revenue
                         { provider: provider }
                         { 
                           total: (+ (get total existing-revenue) amount),
                           pending-withdrawal: (+ (get pending-withdrawal existing-revenue) amount)
                         })
      (map-set provider-revenue
        { provider: provider }
        { total: amount, pending-withdrawal: amount })
    )

;; Execute payment for a subscription
(define-public (process-payment (subscription-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) (err-invalid-subscription)))
      (current-block-height block-height)
    )
    ;; Check if payment is due
    (asserts! (<= (get next-billing subscription) current-block-height) (ok false))
    ;; Check if subscription is active
    (asserts! (is-eq (get status subscription) "active") (err-subscription-expired))
    
    ;; Process payment
    (try! (stx-transfer? (get amount subscription) (get subscriber subscription) (get provider subscription)))
    
    ;; Update provider revenue
    (match (map-get? provider-revenue { provider: (get provider subscription) })
      existing-revenue (map-set provider-revenue
                         { provider: (get provider subscription) }
                         { 
                           total: (+ (get total existing-revenue) (get amount subscription)),
                           pending-withdrawal: (+ (get pending-withdrawal existing-revenue) (get amount subscription))
                         })
      (map-set provider-revenue
        { provider: (get provider subscription) }
        { total: (get amount subscription), pending-withdrawal: (get amount subscription) })
    )
    
    ;; Update next billing cycle
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { next-billing: (+ current-block-height (get period subscription)) })
    )
    
    (ok true)
  )
)

;; Cancel a subscription
(define-public (cancel-subscription (subscription-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) (err-invalid-subscription)))
    )
    ;; Check if caller is the subscriber
    (asserts! (or (is-eq tx-sender (get subscriber subscription))
                 (is-eq tx-sender (get provider subscription)))
             (err-not-authorized))
    
    ;; Check if subscription is active
    (asserts! (is-eq (get status subscription) "active") (err-subscription-expired))
    
    ;; Update subscription status
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { status: "cancelled" })
    )
    
    (ok true)
  )
)

;; Update subscription amount (only provider can do this)
(define-public (update-subscription-amount (subscription-id uint) (new-amount uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) (err-invalid-subscription)))
    )
    ;; Check if caller is the provider
    (asserts! (is-eq tx-sender (get provider subscription)) (err-not-authorized))
    
    ;; Check if subscription is active
    (asserts! (is-eq (get status subscription) "active") (err-subscription-expired))
    
    ;; Validate new amount
    (asserts! (> new-amount u0) (err-invalid-amount))
    
    ;; Update subscription amount
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { amount: new-amount })
    )
    
    (ok true)
  )
)

;; Update subscription period (only provider can do this)
(define-public (update-subscription-period (subscription-id uint) (new-period uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) (err-invalid-subscription)))
    )
    ;; Check if caller is the provider
    (asserts! (is-eq tx-sender (get provider subscription)) (err-not-authorized))
    
    ;; Check if subscription is active
    (asserts! (is-eq (get status subscription) "active") (err-subscription-expired))
    
    ;; Validate new period
    (asserts! (> new-period u0) (err-invalid-period))
    
    ;; Update subscription period
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { period: new-period })
    )
    
    (ok true)
  )
)

;; Toggle auto-renew setting (only subscriber can do this)
(define-public (toggle-auto-renew (subscription-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) (err-invalid-subscription)))
    )
    ;; Check if caller is the subscriber
    (asserts! (is-eq tx-sender (get subscriber subscription)) (err-not-authorized))
    
    ;; Check if subscription is active
    (asserts! (is-eq (get status subscription) "active") (err-subscription-expired))
    
    ;; Toggle auto-renew
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { auto-renew: (not (get auto-renew subscription)) })
    )
    
    (ok true)
  )
)

;; Get subscription details
(define-read-only (get-subscription (subscription-id uint))
  (map-get? subscriptions { subscription-id: subscription-id })
)

;; Get provider subscriptions
(define-read-only (get-provider-subscriptions (provider principal))
  (map-get? provider-subscriptions { provider: provider })
)

;; Get subscriber subscriptions
(define-read-only (get-subscriber-subscriptions (subscriber principal))
  (map-get? subscriber-subscriptions { subscriber: subscriber })
)

;; Get provider revenue info
(define-read-only (get-provider-revenue (provider principal))
  (map-get? provider-revenue { provider: provider })
)


;; Provider withdraws earnings
(define-public (withdraw-earnings)
  (let
    (
      (revenue-data (unwrap! (map-get? provider-revenue { provider: tx-sender }) (err-insufficient-balance)))
      (pending-amount (get pending-withdrawal revenue-data))
    )
    ;; Check if there are funds to withdraw
    (asserts! (> pending-amount u0) (err-insufficient-balance))
    
    ;; Update pending withdrawal amount
    (map-set provider-revenue
      { provider: tx-sender }
      (merge revenue-data { pending-withdrawal: u0 })
    )
    
    ;; Return success
    (ok pending-amount)
  )
)


;; Function to check if subscriptions need renewal
(define-read-only (check-subscription-status (subscription-id uint))
  (let
    (
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) (err-invalid-subscription)))
      (current-block-height block-height)
    )
    (if (<= (get next-billing subscription) current-block-height)
      (ok "payment-due")
      (ok "active")
    )
  )
)

