
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
