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