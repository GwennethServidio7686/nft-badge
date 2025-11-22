;; title: badge-manager
;; version: 1.0.0
;; summary: Core contract managing badge operations, state, and access control
;; description: This contract provides comprehensive badge management functionality including
;;              creation, issuance, revocation, and verification of digital badges on-chain.

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-badge-exists (err u102))
(define-constant err-badge-not-found (err u103))
(define-constant err-invalid-badge-type (err u104))
(define-constant err-already-revoked (err u105))
(define-constant err-recipient-has-badge (err u106))
(define-constant err-invalid-metadata (err u107))

;; Data Variables
(define-data-var badge-id-nonce uint u0)
(define-data-var badge-type-nonce uint u0)
(define-data-var platform-paused bool false)

;; Data Maps

;; Badge type definitions
(define-map badge-types
  uint
  {
    name: (string-ascii 50),
    description: (string-utf8 256),
    metadata-uri: (string-ascii 256),
    issuer: principal,
    active: bool,
    created-at: uint
  }
)

;; Individual badge records
(define-map badges
  uint
  {
    badge-type-id: uint,
    recipient: principal,
    issuer: principal,
    issued-at: uint,
    revoked: bool,
    revoked-at: (optional uint),
    revoked-by: (optional principal),
    metadata-uri: (string-ascii 256)
  }
)

;; Track badges by recipient
(define-map recipient-badges
  { recipient: principal, badge-type-id: uint }
  { badge-id: uint, has-badge: bool }
)

;; Authorized issuers for specific badge types
(define-map authorized-issuers
  { issuer: principal, badge-type-id: uint }
  bool
)

;; Administrator access control
(define-map administrators
  principal
  bool
)

;; Badge issuance count per type
(define-map badge-type-count
  uint
  uint
)

;; Private Functions

(define-private (is-contract-owner (caller principal))
  (is-eq caller contract-owner)
)

(define-private (is-administrator (caller principal))
  (default-to false (map-get? administrators caller))
)

(define-private (is-authorized-issuer (issuer principal) (badge-type-id uint))
  (default-to false (map-get? authorized-issuers { issuer: issuer, badge-type-id: badge-type-id }))
)

(define-private (increment-badge-id)
  (let ((current-id (var-get badge-id-nonce)))
    (var-set badge-id-nonce (+ current-id u1))
    current-id
  )
)

(define-private (increment-badge-type-id)
  (let ((current-id (var-get badge-type-nonce)))
    (var-set badge-type-nonce (+ current-id u1))
    current-id
  )
)

(define-private (increment-badge-type-count (badge-type-id uint))
  (let ((current-count (default-to u0 (map-get? badge-type-count badge-type-id))))
    (map-set badge-type-count badge-type-id (+ current-count u1))
    (ok true)
  )
)

;; Public Functions

;; Initialize contract owner as administrator
(map-set administrators contract-owner true)

;; Add or remove administrators
(define-public (set-administrator (admin principal) (status bool))
  (begin
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (ok (map-set administrators admin status))
  )
)

;; Pause or unpause the platform
(define-public (set-platform-status (paused bool))
  (begin
    (asserts! (or (is-contract-owner tx-sender) (is-administrator tx-sender)) err-not-authorized)
    (ok (var-set platform-paused paused))
  )
)

;; Create a new badge type
(define-public (create-badge-type
    (name (string-ascii 50))
    (description (string-utf8 256))
    (metadata-uri (string-ascii 256))
  )
  (let
    (
      (badge-type-id (increment-badge-type-id))
    )
    (asserts! (not (var-get platform-paused)) err-not-authorized)
    (asserts! (or (is-contract-owner tx-sender) (is-administrator tx-sender)) err-not-authorized)
    (asserts! (> (len name) u0) err-invalid-metadata)
    (ok (map-set badge-types badge-type-id
      {
        name: name,
        description: description,
        metadata-uri: metadata-uri,
        issuer: tx-sender,
        active: true,
        created-at: stacks-block-height
      }
    ))
  )
)

;; Update badge type status
(define-public (set-badge-type-status (badge-type-id uint) (active bool))
  (let
    (
      (badge-type (unwrap! (map-get? badge-types badge-type-id) err-invalid-badge-type))
    )
    (asserts! (or (is-contract-owner tx-sender) (is-administrator tx-sender)) err-not-authorized)
    (ok (map-set badge-types badge-type-id (merge badge-type { active: active })))
  )
)

;; Authorize issuer for a badge type
(define-public (authorize-issuer (issuer principal) (badge-type-id uint))
  (begin
    (asserts! (or (is-contract-owner tx-sender) (is-administrator tx-sender)) err-not-authorized)
    (asserts! (is-some (map-get? badge-types badge-type-id)) err-invalid-badge-type)
    (ok (map-set authorized-issuers { issuer: issuer, badge-type-id: badge-type-id } true))
  )
)

;; Revoke issuer authorization
(define-public (revoke-issuer (issuer principal) (badge-type-id uint))
  (begin
    (asserts! (or (is-contract-owner tx-sender) (is-administrator tx-sender)) err-not-authorized)
    (ok (map-delete authorized-issuers { issuer: issuer, badge-type-id: badge-type-id }))
  )
)

;; Issue a badge to a recipient
(define-public (issue-badge
    (badge-type-id uint)
    (recipient principal)
    (metadata-uri (string-ascii 256))
  )
  (let
    (
      (badge-type (unwrap! (map-get? badge-types badge-type-id) err-invalid-badge-type))
      (badge-id (increment-badge-id))
      (recipient-key { recipient: recipient, badge-type-id: badge-type-id })
    )
    (asserts! (not (var-get platform-paused)) err-not-authorized)
    (asserts! (get active badge-type) err-invalid-badge-type)
    (asserts! (or 
      (is-contract-owner tx-sender)
      (is-administrator tx-sender)
      (is-authorized-issuer tx-sender badge-type-id)
    ) err-not-authorized)
    (asserts! (is-none (map-get? recipient-badges recipient-key)) err-recipient-has-badge)
    
    (map-set badges badge-id
      {
        badge-type-id: badge-type-id,
        recipient: recipient,
        issuer: tx-sender,
        issued-at: stacks-block-height,
        revoked: false,
        revoked-at: none,
        revoked-by: none,
        metadata-uri: metadata-uri
      }
    )
    (map-set recipient-badges recipient-key { badge-id: badge-id, has-badge: true })
    (unwrap-panic (increment-badge-type-count badge-type-id))
    (ok badge-id)
  )
)

;; Revoke a badge
(define-public (revoke-badge (badge-id uint))
  (let
    (
      (badge (unwrap! (map-get? badges badge-id) err-badge-not-found))
      (recipient-key { recipient: (get recipient badge), badge-type-id: (get badge-type-id badge) })
    )
    (asserts! (not (get revoked badge)) err-already-revoked)
    (asserts! (or
      (is-contract-owner tx-sender)
      (is-administrator tx-sender)
      (is-eq tx-sender (get issuer badge))
    ) err-not-authorized)
    
    (map-set badges badge-id (merge badge 
      {
        revoked: true,
        revoked-at: (some stacks-block-height),
        revoked-by: (some tx-sender)
      }
    ))
    (map-set recipient-badges recipient-key { badge-id: badge-id, has-badge: false })
    (ok true)
  )
)

;; Read-only Functions

;; Get badge type information
(define-read-only (get-badge-type (badge-type-id uint))
  (map-get? badge-types badge-type-id)
)

;; Get badge information
(define-read-only (get-badge (badge-id uint))
  (map-get? badges badge-id)
)

;; Check if recipient has a specific badge type
(define-read-only (has-badge (recipient principal) (badge-type-id uint))
  (match (map-get? recipient-badges { recipient: recipient, badge-type-id: badge-type-id })
    badge-data (get has-badge badge-data)
    false
  )
)

;; Get badge ID for recipient and badge type
(define-read-only (get-recipient-badge-id (recipient principal) (badge-type-id uint))
  (get badge-id (map-get? recipient-badges { recipient: recipient, badge-type-id: badge-type-id }))
)

;; Verify if a badge is valid (exists and not revoked)
(define-read-only (verify-badge (badge-id uint))
  (match (map-get? badges badge-id)
    badge (ok (not (get revoked badge)))
    err-badge-not-found
  )
)

;; Check if address is an administrator
(define-read-only (is-admin (address principal))
  (default-to false (map-get? administrators address))
)

;; Check if issuer is authorized for badge type
(define-read-only (check-issuer-authorization (issuer principal) (badge-type-id uint))
  (default-to false (map-get? authorized-issuers { issuer: issuer, badge-type-id: badge-type-id }))
)

;; Get total badges issued for a badge type
(define-read-only (get-badge-type-issuance-count (badge-type-id uint))
  (default-to u0 (map-get? badge-type-count badge-type-id))
)

;; Get current badge ID nonce
(define-read-only (get-next-badge-id)
  (var-get badge-id-nonce)
)

;; Get current badge type ID nonce
(define-read-only (get-next-badge-type-id)
  (var-get badge-type-nonce)
)

;; Check if platform is paused
(define-read-only (is-platform-paused)
  (var-get platform-paused)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  contract-owner
)

