
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
