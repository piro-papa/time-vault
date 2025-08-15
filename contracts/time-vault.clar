;; Title: TimeVault
;; Summary: Decentralized temporal access control for premium gaming experiences
;; Description: TimeVault revolutionizes digital entertainment through blockchain-native 
;;              time banking. Players mint temporal credits that unlock exclusive gaming 
;;              sessions, with each credit representing verified blockchain time units. 
;;              The protocol ensures fair play distribution, prevents time manipulation, 
;;              and creates a sustainable economy where premium gaming time becomes a 
;;              tradeable digital asset backed by cryptographic proof of temporal commitment.

;; CONSTANTS & ERRORS

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_TIME_DURATION (err u201))
(define-constant ERR_INSUFFICIENT_BALANCE (err u202))
(define-constant ERR_ACTIVE_SESSION_EXISTS (err u203))
(define-constant ERR_NO_ACTIVE_SESSION (err u204))
(define-constant ERR_SESSION_EXPIRED (err u205))
(define-constant ERR_INVALID_TIER_CONFIG (err u206))
(define-constant ERR_MALFORMED_INPUT (err u207))
(define-constant ERR_ARITHMETIC_OVERFLOW (err u208))

;; Security & Validation Bounds
(define-constant MAX_TIER_LIMIT u100)
(define-constant MAX_BLOCK_COST u1000000) ;; 1M STX maximum per block
(define-constant MAX_SESSION_LENGTH u525600) ;; ~10 years theoretical max
(define-constant MIN_BLOCK_COST u1) ;; Minimum viable cost
(define-constant MAX_IDENTIFIER_LENGTH u64)

;; STATE VARIABLES

(define-data-var contract-owner principal tx-sender)
(define-data-var next-user-id uint u1)
(define-data-var highest-tier-id uint u2)

;; STORAGE MAPPINGS=

(define-map access-tiers
  { tier-id: uint }
  {
    tier-name: (string-ascii 64),
    block-rate: uint,
    min-session-blocks: uint,
    max-session-blocks: uint,
    tier-active: bool,
  }
)

(define-map user-sessions
  { user: principal }
  {
    user-id: uint,
    current-tier: uint,
    session-start: uint,
    session-end: uint,
    renewal-enabled: bool,
    lifetime-expenditure: uint,
  }
)

(define-map session-registry
  { user-id: uint }
  {
    user-principal: principal,
    tier-assignment: uint,
    activation-block: uint,
    expiration-block: uint,
    auto-renewal: bool,
    total-investment: uint,
    session-status: bool,
  }
)

;; INITIAL TIER DEPLOYMENT

;; Standard Tier Configuration
(map-set access-tiers { tier-id: u1 } {
  tier-name: "Standard Access",
  block-rate: u12,
  min-session-blocks: u4320, ;; ~30 days minimum
  max-session-blocks: u52560, ;; ~365 days maximum
  tier-active: true,
})

;; Premium Tier Configuration
(map-set access-tiers { tier-id: u2 } {
  tier-name: "Premium Access",
  block-rate: u25,
  min-session-blocks: u4320,
  max-session-blocks: u52560,
  tier-active: true,
})

;; VALIDATION UTILITIES

(define-private (validate-tier-id (tier-id uint))
  (and (> tier-id u0) (<= tier-id MAX_TIER_LIMIT))
)

(define-private (validate-block-cost (cost uint))
  (and (>= cost MIN_BLOCK_COST) (<= cost MAX_BLOCK_COST))
)

(define-private (validate-session-duration (duration uint))
  (and (> duration u0) (<= duration MAX_SESSION_LENGTH))
)

(define-private (validate-duration-boundaries
    (min-duration uint)
    (max-duration uint)
  )
  (and
    (validate-session-duration min-duration)
    (validate-session-duration max-duration)
    (<= min-duration max-duration)
  )
)

(define-private (secure-multiply
    (operand-a uint)
    (operand-b uint)
  )
  (let ((product (* operand-a operand-b)))
    (if (and (> operand-a u0) (> operand-b u0))
      ;; Overflow detection: if a * b / a != b, overflow occurred
      (if (is-eq (/ product operand-a) operand-b)
        (ok product)
        ERR_ARITHMETIC_OVERFLOW
      )
      (ok product)
    )
  )
)

(define-private (secure-addition
    (addend-a uint)
    (addend-b uint)
  )
  (let ((sum (+ addend-a addend-b)))
    (if (>= sum addend-a)
      (ok sum)
      ERR_ARITHMETIC_OVERFLOW
    )
  )
)

;; READ-ONLY FUNCTIONS

(define-read-only (fetch-tier-details (tier-id uint))
  (if (validate-tier-id tier-id)
    (map-get? access-tiers { tier-id: tier-id })
    none
  )
)

(define-read-only (fetch-user-session (user principal))
  (map-get? user-sessions { user: user })
)

(define-read-only (fetch-session-by-id (user-id uint))
  (map-get? session-registry { user-id: user-id })
)

(define-read-only (verify-active-session (user principal))
  (match (map-get? user-sessions { user: user })
    session-data (>= (get session-end session-data) stacks-block-height)
    false
  )
)

(define-read-only (calculate-remaining-blocks (user principal))
  (match (map-get? user-sessions { user: user })
    session-data (if (>= (get session-end session-data) stacks-block-height)
      (some (- (get session-end session-data) stacks-block-height))
      (some u0)
    )
    none
  )
)

(define-read-only (compute-session-cost
    (tier-id uint)
    (block-count uint)
  )
  (begin
    ;; Input validation
    (asserts! (validate-tier-id tier-id) ERR_INVALID_TIER_CONFIG)
    (asserts! (validate-session-duration block-count) ERR_INVALID_TIME_DURATION)

    (match (map-get? access-tiers { tier-id: tier-id })
      tier-config (if (and
          (>= block-count (get min-session-blocks tier-config))
          (<= block-count (get max-session-blocks tier-config))
          (get tier-active tier-config)
        )
        ;; Secure arithmetic to prevent overflow
        (secure-multiply (get block-rate tier-config) block-count)
        ERR_INVALID_TIME_DURATION
      )
      ERR_INVALID_TIER_CONFIG
    )
  )
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-highest-tier-id)
  (var-get highest-tier-id)
)

;; PUBLIC PLAYER FUNCTIONS

(define-public (initialize-session
    (tier-id uint)
    (session-blocks uint)
    (auto-renewal bool)
  )
  (let (
      (user tx-sender)
      (current-block stacks-block-height)
      (new-user-id (var-get next-user-id))
    )
    ;; Comprehensive input validation
    (asserts! (validate-tier-id tier-id) ERR_INVALID_TIER_CONFIG)
    (asserts! (validate-session-duration session-blocks)
      ERR_INVALID_TIME_DURATION
    )

    ;; Prevent duplicate active sessions
    (asserts! (not (verify-active-session user)) ERR_ACTIVE_SESSION_EXISTS)

    ;; Calculate and validate session cost
    (match (compute-session-cost tier-id session-blocks)
      session-cost (let (
        )
        ;; Secure block arithmetic
        (match (secure-addition current-block session-blocks)
          session-end-block (begin
            ;; Create comprehensive user session record
            (map-set user-sessions { user: user } {
              user-id: new-user-id,
              current-tier: tier-id,
              session-start: current-block,
              session-end: session-end-block,
              renewal-enabled: auto-renewal,
              lifetime-expenditure: session-cost,
            })

            ;; Maintain session registry for administrative oversight
            (map-set session-registry { user-id: new-user-id } {
              user-principal: user,
              tier-assignment: tier-id,
              activation-block: current-block,
              expiration-block: session-end-block,
              auto-renewal: auto-renewal,
              total-investment: session-cost,
              session-status: true,
            })

            ;; Atomically increment user counter
            (var-set next-user-id (+ new-user-id u1))

            ;; Execute payment transfer
            (try! (stx-transfer? session-cost user (var-get contract-owner)))

            (ok new-user-id)
          )
          arithmetic-error (err arithmetic-error)
        )
      )
      cost-error (err cost-error)
    )
  )
)

(define-public (extend-session-duration (additional-blocks uint))
  (let ((user tx-sender))
    ;; Validate extension request
    (asserts! (validate-session-duration additional-blocks)
      ERR_INVALID_TIME_DURATION
    )

    (match (map-get? user-sessions { user: user })
      session-data (let (
          (current-tier (get current-tier session-data))
          (current-expiration (get session-end session-data))
        )
        ;; Calculate extension cost with current tier rates
        (match (compute-session-cost current-tier additional-blocks)
          extension-cost (begin
            ;; Secure arithmetic for new expiration and total cost
            (match (secure-addition current-expiration additional-blocks)
              new-expiration (match (secure-addition (get lifetime-expenditure session-data)
                extension-cost
              )
                updated-total (begin
                  ;; Update user session with extension
                  (map-set user-sessions { user: user }
                    (merge session-data {
                      session-end: new-expiration,
                      lifetime-expenditure: updated-total,
                    })
                  )

                  ;; Synchronize session registry
                  (map-set session-registry { user-id: (get user-id session-data) }
                    (merge
                      (unwrap-panic (map-get? session-registry { user-id: (get user-id session-data) })) {
                      expiration-block: new-expiration,
                      total-investment: updated-total,
                    })
                  )

                  ;; Process extension payment
                  (try! (stx-transfer? extension-cost user (var-get contract-owner)))

                  (ok new-expiration)
                )
                arithmetic-error (err arithmetic-error)
              )
              arithmetic-error (err arithmetic-error)
            )
          )
          cost-error (err cost-error)
        )
      )
      ERR_NO_ACTIVE_SESSION
    )
  )
)

(define-public (terminate-session)
  (let ((user tx-sender))
    (match (map-get? user-sessions { user: user })
      session-data (begin
        ;; Deactivate session in registry
        (map-set session-registry { user-id: (get user-id session-data) }
          (merge
            (unwrap-panic (map-get? session-registry { user-id: (get user-id session-data) })) {
            session-status: false,
            auto-renewal: false,
          })
        )

        ;; Immediately terminate user session
        (map-set user-sessions { user: user }
          (merge session-data {
            renewal-enabled: false,
            session-end: stacks-block-height, ;; Immediate termination
          })
        )

        (ok true)
      )
      ERR_NO_ACTIVE_SESSION
    )
  )
)

(define-public (toggle-renewal-setting)
  (let ((user tx-sender))
    (match (map-get? user-sessions { user: user })
      session-data (let ((updated-renewal (not (get renewal-enabled session-data))))
        ;; Update user session renewal preference
        (map-set user-sessions { user: user }
          (merge session-data { renewal-enabled: updated-renewal })
        )

        ;; Synchronize registry with preference change
        (map-set session-registry { user-id: (get user-id session-data) }
          (merge
            (unwrap-panic (map-get? session-registry { user-id: (get user-id session-data) })) { auto-renewal: updated-renewal }
          ))

        (ok updated-renewal)
      )
      ERR_NO_ACTIVE_SESSION
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

(define-public (deploy-new-tier
    (tier-name (string-ascii 64))
    (block-rate uint)
    (min-blocks uint)
    (max-blocks uint)
  )
  (let ((new-tier-id (+ (var-get highest-tier-id) u1)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)

    ;; Comprehensive input validation
    (asserts! (> (len tier-name) u0) ERR_MALFORMED_INPUT)
    (asserts! (validate-block-cost block-rate) ERR_MALFORMED_INPUT)
    (asserts! (validate-duration-boundaries min-blocks max-blocks)
      ERR_MALFORMED_INPUT
    )
    (asserts! (<= new-tier-id MAX_TIER_LIMIT) ERR_INVALID_TIER_CONFIG)

    ;; Deploy new tier with validated configuration
    (map-set access-tiers { tier-id: new-tier-id } {
      tier-name: tier-name,
      block-rate: block-rate,
      min-session-blocks: min-blocks,
      max-session-blocks: max-blocks,
      tier-active: true,
    })

    ;; Update tier counter
    (var-set highest-tier-id new-tier-id)

    (ok new-tier-id)
  )
)

(define-public (modify-tier-configuration
    (tier-id uint)
    (tier-name (string-ascii 64))
    (block-rate uint)
    (min-blocks uint)
    (max-blocks uint)
    (active-status bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)

    ;; Comprehensive validation suite
    (asserts! (validate-tier-id tier-id) ERR_INVALID_TIER_CONFIG)
    (asserts! (is-some (map-get? access-tiers { tier-id: tier-id }))
      ERR_INVALID_TIER_CONFIG
    )
    (asserts! (> (len tier-name) u0) ERR_MALFORMED_INPUT)
    (asserts! (validate-block-cost block-rate) ERR_MALFORMED_INPUT)
    (asserts! (validate-duration-boundaries min-blocks max-blocks)
      ERR_MALFORMED_INPUT
    )

    ;; Apply configuration changes
    (map-set access-tiers { tier-id: tier-id } {
      tier-name: tier-name,
      block-rate: block-rate,
      min-session-blocks: min-blocks,
      max-session-blocks: max-blocks,
      tier-active: active-status,
    })

    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Prevent self-transfer
    (asserts! (not (is-eq new-owner (var-get contract-owner)))
      ERR_MALFORMED_INPUT
    )
    ;; Execute ownership transfer
    (var-set contract-owner new-owner)
    (ok true)
  )
)
