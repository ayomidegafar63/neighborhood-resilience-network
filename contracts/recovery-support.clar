;; Neighborhood Resilience Network - Recovery Support Contract
;; Organize mutual aid and recovery support after emergencies

;; Data Variables
(define-data-var recovery-case-counter uint u0)
(define-data-var aid-request-counter uint u0)
(define-data-var admin principal tx-sender)
(define-data-var total-aid-distributed uint u0)

;; Constants
(define-constant ERR-UNAUTHORIZED (err u600))
(define-constant ERR-CASE-NOT-FOUND (err u601))
(define-constant ERR-REQUEST-NOT-FOUND (err u602))
(define-constant ERR-INVALID-STATUS (err u603))
(define-constant ERR-INVALID-PRIORITY (err u604))
(define-constant ERR-INSUFFICIENT-RESOURCES (err u605))
(define-constant ERR-ALREADY-FULFILLED (err u606))

;; Recovery Case Status
(define-constant STATUS-ASSESSMENT u1)
(define-constant STATUS-PLANNING u2)
(define-constant STATUS-ACTIVE u3)
(define-constant STATUS-MONITORING u4)
(define-constant STATUS-COMPLETED u5)

;; Aid Request Priority
(define-constant PRIORITY-URGENT u1)
(define-constant PRIORITY-HIGH u2)
(define-constant PRIORITY-MEDIUM u3)
(define-constant PRIORITY-LOW u4)

;; Aid Request Status
(define-constant AID-STATUS-PENDING u1)
(define-constant AID-STATUS-APPROVED u2)
(define-constant AID-STATUS-ALLOCATED u3)
(define-constant AID-STATUS-DELIVERED u4)
(define-constant AID-STATUS-COMPLETED u5)
(define-constant AID-STATUS-REJECTED u6)

;; Recovery Case Data Structure
(define-map recovery-cases uint {
    id: uint,
    incident-reference: uint,
    case-manager: principal,
    affected-area: (string-ascii 200),
    affected-households: uint,
    estimated-recovery-time: uint,
    total-damage-assessment: uint,
    status: uint,
    priority-level: uint,
    resources-allocated: uint,
    resources-used: uint,
    community-volunteers: uint,
    progress-percentage: uint,
    created-at: uint,
    updated-at: uint
})

;; Aid Request Data Structure
(define-map aid-requests uint {
    id: uint,
    recovery-case-id: uint,
    requester: principal,
    request-type: (string-ascii 100),
    description: (string-ascii 400),
    urgency-level: uint,
    estimated-cost: uint,
    quantity-needed: uint,
    delivery-location: (string-ascii 200),
    contact-info: (string-ascii 150),
    status: uint,
    approved-amount: uint,
    fulfillment-deadline: uint,
    requested-at: uint,
    fulfilled-at: (optional uint)
})

;; Mutual Aid Network
(define-map mutual-aid-providers principal {
    provider-name: (string-ascii 100),
    aid-types-offered: (string-ascii 300),
    availability-status: uint,
    total-aid-provided: uint,
    reliability-rating: uint,
    contact-method: (string-ascii 100),
    service-area: (string-ascii 200),
    registered-at: uint
})

;; Recovery Plans
(define-map recovery-plans {case-id: uint, plan-id: uint} {
    plan-id: uint,
    plan-name: (string-ascii 100),
    description: (string-ascii 500),
    target-completion: uint,
    resource-requirements: (string-ascii 300),
    responsible-parties: (string-ascii 200),
    milestones: uint,
    status: uint,
    created-at: uint
})

;; Aid Fulfillment Tracking
(define-map aid-fulfillments {request-id: uint, provider: principal} {
    provider-name: (string-ascii 100),
    aid-type: (string-ascii 100),
    quantity-provided: uint,
    delivery-method: (string-ascii 100),
    delivery-status: uint,
    provided-at: uint,
    quality-rating: (optional uint)
})

;; Community Support Networks
(define-map support-networks (string-ascii 100) {
    network-name: (string-ascii 100),
    coordinator: principal,
    focus-area: (string-ascii 200),
    member-count: uint,
    active-cases: uint,
    total-aid-coordinated: uint,
    established-date: uint
})

;; Resilience Assessments
(define-map resilience-assessments {case-id: uint, assessment-id: uint} {
    assessment-id: uint,
    assessor: principal,
    vulnerability-areas: (string-ascii 300),
    improvement-recommendations: (string-ascii 500),
    risk-reduction-score: uint,
    community-preparedness-score: uint,
    infrastructure-resilience-score: uint,
    conducted-at: uint
})

;; Create recovery case
(define-public (create-recovery-case (incident-reference uint) (affected-area (string-ascii 200)) (affected-households uint)
                                    (estimated-recovery-time uint) (total-damage-assessment uint) (priority-level uint))
    (let (
        (case-id (+ (var-get recovery-case-counter) u1))
        (current-height stacks-block-height)
    )
        (asserts! (and (>= priority-level PRIORITY-URGENT) (<= priority-level PRIORITY-LOW)) ERR-INVALID-PRIORITY)
        
        (map-set recovery-cases case-id {
            id: case-id,
            incident-reference: incident-reference,
            case-manager: tx-sender,
            affected-area: affected-area,
            affected-households: affected-households,
            estimated-recovery-time: estimated-recovery-time,
            total-damage-assessment: total-damage-assessment,
            status: STATUS-ASSESSMENT,
            priority-level: priority-level,
            resources-allocated: u0,
            resources-used: u0,
            community-volunteers: u0,
            progress-percentage: u0,
            created-at: current-height,
            updated-at: current-height
        })
        
        (var-set recovery-case-counter case-id)
        (ok case-id)
    )
)

;; Submit aid request
(define-public (submit-aid-request (recovery-case-id uint) (request-type (string-ascii 100)) (description (string-ascii 400))
                                  (urgency-level uint) (estimated-cost uint) (quantity-needed uint)
                                  (delivery-location (string-ascii 200)) (contact-info (string-ascii 150)) (fulfillment-deadline uint))
    (let (
        (request-id (+ (var-get aid-request-counter) u1))
        (current-height stacks-block-height)
    )
        (asserts! (is-some (map-get? recovery-cases recovery-case-id)) ERR-CASE-NOT-FOUND)
        (asserts! (and (>= urgency-level PRIORITY-URGENT) (<= urgency-level PRIORITY-LOW)) ERR-INVALID-PRIORITY)
        
        (map-set aid-requests request-id {
            id: request-id,
            recovery-case-id: recovery-case-id,
            requester: tx-sender,
            request-type: request-type,
            description: description,
            urgency-level: urgency-level,
            estimated-cost: estimated-cost,
            quantity-needed: quantity-needed,
            delivery-location: delivery-location,
            contact-info: contact-info,
            status: AID-STATUS-PENDING,
            approved-amount: u0,
            fulfillment-deadline: fulfillment-deadline,
            requested-at: current-height,
            fulfilled-at: none
        })
        
        (var-set aid-request-counter request-id)
        (ok request-id)
    )
)

;; Register as mutual aid provider
(define-public (register-aid-provider (provider-name (string-ascii 100)) (aid-types-offered (string-ascii 300))
                                     (contact-method (string-ascii 100)) (service-area (string-ascii 200)))
    (let (
        (current-height stacks-block-height)
    )
        (map-set mutual-aid-providers tx-sender {
            provider-name: provider-name,
            aid-types-offered: aid-types-offered,
            availability-status: u1,
            total-aid-provided: u0,
            reliability-rating: u5,
            contact-method: contact-method,
            service-area: service-area,
            registered-at: current-height
        })
        
        (ok true)
    )
)

;; Approve aid request
(define-public (approve-aid-request (request-id uint) (approved-amount uint))
    (let (
        (request (unwrap! (map-get? aid-requests request-id) ERR-REQUEST-NOT-FOUND))
        (recovery-case (unwrap! (map-get? recovery-cases (get recovery-case-id request)) ERR-CASE-NOT-FOUND))
    )
        (asserts! (or (is-eq tx-sender (get case-manager recovery-case)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status request) AID-STATUS-PENDING) ERR-INVALID-STATUS)
        
        (map-set aid-requests request-id (merge request {
            status: AID-STATUS-APPROVED,
            approved-amount: approved-amount
        }))
        
        (ok true)
    )
)

;; Fulfill aid request
(define-public (fulfill-aid-request (request-id uint) (provider-name (string-ascii 100)) (quantity-provided uint) (delivery-method (string-ascii 100)))
    (let (
        (request (unwrap! (map-get? aid-requests request-id) ERR-REQUEST-NOT-FOUND))
        (provider (unwrap! (map-get? mutual-aid-providers tx-sender) ERR-UNAUTHORIZED))
        (current-height stacks-block-height)
    )
        (asserts! (is-eq (get status request) AID-STATUS-APPROVED) ERR-INVALID-STATUS)
        (asserts! (is-eq (get availability-status provider) u1) ERR-INVALID-STATUS)
        
        ;; Record fulfillment
        (map-set aid-fulfillments {request-id: request-id, provider: tx-sender} {
            provider-name: provider-name,
            aid-type: (get request-type request),
            quantity-provided: quantity-provided,
            delivery-method: delivery-method,
            delivery-status: u1,
            provided-at: current-height,
            quality-rating: none
        })
        
        ;; Update request status
        (map-set aid-requests request-id (merge request {
            status: AID-STATUS-DELIVERED,
            fulfilled-at: (some current-height)
        }))
        
        ;; Update provider stats
        (map-set mutual-aid-providers tx-sender (merge provider {
            total-aid-provided: (+ (get total-aid-provided provider) u1)
        }))
        
        ;; Update global counter
        (var-set total-aid-distributed (+ (var-get total-aid-distributed) quantity-provided))
        
        (ok true)
    )
)

;; Create recovery plan
(define-public (create-recovery-plan (case-id uint) (plan-name (string-ascii 100)) (description (string-ascii 500))
                                    (target-completion uint) (resource-requirements (string-ascii 300)) (responsible-parties (string-ascii 200)))
    (let (
        (recovery-case (unwrap! (map-get? recovery-cases case-id) ERR-CASE-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (or (is-eq tx-sender (get case-manager recovery-case)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        
        (map-set recovery-plans {case-id: case-id, plan-id: current-height} {
            plan-id: current-height,
            plan-name: plan-name,
            description: description,
            target-completion: target-completion,
            resource-requirements: resource-requirements,
            responsible-parties: responsible-parties,
            milestones: u0,
            status: u1,
            created-at: current-height
        })
        
        (ok current-height)
    )
)

;; Update recovery case progress
(define-public (update-recovery-progress (case-id uint) (new-progress uint) (resources-used uint) (volunteer-count uint))
    (let (
        (recovery-case (unwrap! (map-get? recovery-cases case-id) ERR-CASE-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (is-eq tx-sender (get case-manager recovery-case)) ERR-UNAUTHORIZED)
        (asserts! (<= new-progress u100) ERR-INVALID-STATUS)
        
        (map-set recovery-cases case-id (merge recovery-case {
            progress-percentage: new-progress,
            resources-used: resources-used,
            community-volunteers: volunteer-count,
            status: (if (is-eq new-progress u100) STATUS-COMPLETED (get status recovery-case)),
            updated-at: current-height
        }))
        
        (ok true)
    )
)

;; Conduct resilience assessment
(define-public (conduct-resilience-assessment (case-id uint) (vulnerability-areas (string-ascii 300)) (improvement-recommendations (string-ascii 500))
                                             (risk-reduction-score uint) (community-preparedness-score uint) (infrastructure-resilience-score uint))
    (let (
        (recovery-case (unwrap! (map-get? recovery-cases case-id) ERR-CASE-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (or (is-eq tx-sender (get case-manager recovery-case)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        (asserts! (and (<= risk-reduction-score u10) (<= community-preparedness-score u10) (<= infrastructure-resilience-score u10)) ERR-INVALID-STATUS)
        
        (map-set resilience-assessments {case-id: case-id, assessment-id: current-height} {
            assessment-id: current-height,
            assessor: tx-sender,
            vulnerability-areas: vulnerability-areas,
            improvement-recommendations: improvement-recommendations,
            risk-reduction-score: risk-reduction-score,
            community-preparedness-score: community-preparedness-score,
            infrastructure-resilience-score: infrastructure-resilience-score,
            conducted-at: current-height
        })
        
        (ok current-height)
    )
)

;; Create support network
(define-public (create-support-network (network-name (string-ascii 100)) (focus-area (string-ascii 200)))
    (let (
        (current-height stacks-block-height)
    )
        (map-set support-networks network-name {
            network-name: network-name,
            coordinator: tx-sender,
            focus-area: focus-area,
            member-count: u1,
            active-cases: u0,
            total-aid-coordinated: u0,
            established-date: current-height
        })
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-recovery-case (case-id uint))
    (map-get? recovery-cases case-id)
)

(define-read-only (get-aid-request (request-id uint))
    (map-get? aid-requests request-id)
)

(define-read-only (get-aid-provider (provider principal))
    (map-get? mutual-aid-providers provider)
)

(define-read-only (get-recovery-plan (case-id uint) (plan-id uint))
    (map-get? recovery-plans {case-id: case-id, plan-id: plan-id})
)

(define-read-only (get-aid-fulfillment (request-id uint) (provider principal))
    (map-get? aid-fulfillments {request-id: request-id, provider: provider})
)

(define-read-only (get-support-network (network-name (string-ascii 100)))
    (map-get? support-networks network-name)
)

(define-read-only (get-resilience-assessment (case-id uint) (assessment-id uint))
    (map-get? resilience-assessments {case-id: case-id, assessment-id: assessment-id})
)

(define-read-only (get-recovery-case-count)
    (var-get recovery-case-counter)
)

(define-read-only (get-aid-request-count)
    (var-get aid-request-counter)
)

(define-read-only (get-total-aid-distributed)
    (var-get total-aid-distributed)
)

(define-read-only (get-admin)
    (var-get admin)
)

;; Check if case needs urgent attention
(define-read-only (needs-urgent-attention (case-id uint))
    (match (map-get? recovery-cases case-id)
        recovery-case (and (is-eq (get priority-level recovery-case) PRIORITY-URGENT)
                          (< (get progress-percentage recovery-case) u50))
        false
    )
)
