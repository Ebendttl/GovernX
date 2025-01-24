;; GovernX
;; Advanced governance token with proposal voting and minting capabilities

;; constants
(define-constant ERR-NOT-OWNER (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INVALID-PROPOSAL (err u3))
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-CAP u1000000)

;; data maps and vars
(define-fungible-token gov-token)
(define-data-var total-minted uint u0)
(define-data-var proposal-counter uint u0)

(define-map proposals
  {proposal-id: uint}
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    is-active: bool
  }
)

(define-map voter-voted
  {proposal-id: uint, voter: principal}
  bool
)

;; private functions
(define-private (record-vote (proposal-id uint) (vote-type bool) (voter principal) (voter-balance uint))
  (let 
    (
      (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR-INVALID-PROPOSAL))
    )
    (begin
      ;; Check proposal is active
      (asserts! (get is-active proposal) ERR-INVALID-PROPOSAL)

      ;; Prevent double voting
      (asserts! (is-none (map-get? voter-voted {proposal-id: proposal-id, voter: voter})) ERR-INVALID-PROPOSAL)

      ;; Mark voter as voted
      (map-set voter-voted {proposal-id: proposal-id, voter: voter} true)

      ;; Record vote
      (if vote-type
        (map-set proposals 
          {proposal-id: proposal-id}
          (merge proposal {votes-for: (+ (get votes-for proposal) voter-balance)})
        )
        (map-set proposals 
          {proposal-id: proposal-id}
          (merge proposal {votes-against: (+ (get votes-against proposal) voter-balance)})
        )
      )

      (ok true)
    )
  )
)

;; public functions
(define-public (mint (amount uint))
  (let 
    (
      (current-minted (var-get total-minted))
    )
    (begin
      ;; Check if minting would exceed cap
      (asserts! (< (+ current-minted amount) TOKEN-CAP) ERR-INSUFFICIENT-BALANCE)
      
      ;; Only owner can mint
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
      
      ;; Update total minted
      (var-set total-minted (+ current-minted amount))
      
      ;; Mint tokens
      (ft-mint? gov-token amount tx-sender)
    )
  )
)

(define-public (transfer (recipient principal) (amount uint))
  (begin
    ;; Ensure sufficient balance
    (asserts! (>= (ft-get-balance gov-token tx-sender) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Perform transfer
    (ft-transfer? gov-token amount tx-sender recipient)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let 
    (
      (proposal-id (+ (var-get proposal-counter) u1))
    )
    (begin
      ;; Only token holders can create proposals
      (asserts! (> (ft-get-balance gov-token tx-sender) u0) ERR-NOT-OWNER)
      
      ;; Store proposal
      (map-set proposals 
        {proposal-id: proposal-id}
        {
          title: title,
          description: description,
          votes-for: u0,
          votes-against: u0,
          is-active: true
        }
      )
      
      ;; Increment proposal counter
      (var-set proposal-counter proposal-id)
      
      (ok proposal-id)
    )
  )
)

;; Initial setup
(begin
  (ft-mint? gov-token u10000 CONTRACT-OWNER)
)

;; Vote on a proposal
(define-public (vote (proposal-id uint) (vote-type bool))
  (let 
    (
      (voter tx-sender)
      (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR-INVALID-PROPOSAL))
      (voter-balance (ft-get-balance gov-token voter))
    )
    (begin
      ;; Check proposal is active
      (asserts! (get is-active proposal) ERR-INVALID-PROPOSAL)

      ;; Prevent double voting
      (asserts! (is-none (map-get? voter-voted {proposal-id: proposal-id, voter: voter})) ERR-INVALID-PROPOSAL)

      ;; Mark voter as voted
      (map-set voter-voted {proposal-id: proposal-id, voter: voter} true)

      ;; Record vote
      (if vote-type
        (map-set proposals 
          {proposal-id: proposal-id}
          (merge proposal {votes-for: (+ (get votes-for proposal) voter-balance)})
        )
        (map-set proposals 
          {proposal-id: proposal-id}
          (merge proposal {votes-against: (+ (get votes-against proposal) voter-balance)})
        )
      )

      (ok true)
    )
  )
)