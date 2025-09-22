;; Neighborhood Resilience Network - Resource Inventory Contract
;; Inventory emergency supplies and skills across the neighborhood

;; Data Variables
(define-data-var resource-counter uint u0)
(define-data-var skill-counter uint u0)
(define-data-var admin principal tx-sender)

;; Constants
(define-constant ERR-UNAUTHORIZED (err u400))
(define-constant ERR-RESOURCE-NOT-FOUND (err u401))
(define-constant ERR-SKILL-NOT-FOUND (err u402))
(define-constant ERR-INVALID-STATUS (err u403))
(define-constant ERR-ALREADY-REGISTERED (err u404))
(define-constant ERR-INVALID-QUANTITY (err u405))
(define-constant ERR-RESOURCE-UNAVAILABLE (err u406))

;; Resource Status
(define-constant STATUS-AVAILABLE u1)
(define-constant STATUS-RESERVED u2)
(define-constant STATUS-IN-USE u3)
(define-constant STATUS-MAINTENANCE u4)
(define-constant STATUS-RETIRED u5)

;; Resource Priority Levels
(define-constant PRIORITY-CRITICAL u1)
(define-constant PRIORITY-HIGH u2)
(define-constant PRIORITY-MEDIUM u3)
(define-constant PRIORITY-LOW u4)

;; Resource Data Structure
(define-map resources uint {
    id: uint,
    owner: principal,
    resource-type: (string-ascii 100),
    name: (string-ascii 100),
    description: (string-ascii 300),
    quantity-available: uint,
    quantity-total: uint,
    location: (string-ascii 200),
    contact-info: (string-ascii 150),
    status: uint,
    priority-level: uint,
    expiration-date: (optional uint),
    last-updated: uint,
    created-at: uint
})

;; Skills Inventory
(define-map skills uint {
    id: uint,
    provider: principal,
    skill-name: (string-ascii 100),
    skill-category: (string-ascii 50),
    proficiency-level: uint,
    certification: (string-ascii 200),
    availability-hours: (string-ascii 100),
    contact-method: (string-ascii 100),
    active: bool,
    volunteer-since: uint,
    total-hours-volunteered: uint
})

;; Resource Reservations
(define-map reservations {resource-id: uint, requester: principal} {
    quantity-reserved: uint,
    reserved-at: uint,
    expires-at: uint,
    purpose: (string-ascii 200),
    status: uint
})

;; Skill Assignments
(define-map skill-assignments {skill-id: uint, incident-id: uint} {
    assigned-at: uint,
    estimated-hours: uint,
    actual-hours: uint,
    status: uint,
    notes: (string-ascii 300)
})

;; Resource Categories
(define-map resource-categories (string-ascii 100) {
    category-name: (string-ascii 100),
    description: (string-ascii 300),
    critical-threshold: uint,
    active: bool
})

;; Community Members
(define-map community-members principal {
    member-since: uint,
    resources-shared: uint,
    skills-offered: uint,
    reliability-score: uint,
    contact-preference: (string-ascii 50),
    availability-status: uint
})

;; Register a resource
(define-public (register-resource (resource-type (string-ascii 100)) (name (string-ascii 100)) (description (string-ascii 300))
                                 (quantity uint) (location (string-ascii 200)) (contact-info (string-ascii 150))
                                 (priority-level uint) (expiration-date (optional uint)))
    (let (
        (resource-id (+ (var-get resource-counter) u1))
        (current-height stacks-block-height)
    )
        (asserts! (and (>= priority-level PRIORITY-CRITICAL) (<= priority-level PRIORITY-LOW)) ERR-INVALID-STATUS)
        (asserts! (> quantity u0) ERR-INVALID-QUANTITY)
        
        (map-set resources resource-id {
            id: resource-id,
            owner: tx-sender,
            resource-type: resource-type,
            name: name,
            description: description,
            quantity-available: quantity,
            quantity-total: quantity,
            location: location,
            contact-info: contact-info,
            status: STATUS-AVAILABLE,
            priority-level: priority-level,
            expiration-date: expiration-date,
            last-updated: current-height,
            created-at: current-height
        })
        
        ;; Update community member stats
        (let (
            (member-info (default-to {member-since: current-height, resources-shared: u0, skills-offered: u0,
                                     reliability-score: u5, contact-preference: "phone", availability-status: u1}
                                    (map-get? community-members tx-sender)))
        )
            (map-set community-members tx-sender (merge member-info {
                resources-shared: (+ (get resources-shared member-info) u1)
            }))
        )
        
        (var-set resource-counter resource-id)
        (ok resource-id)
    )
)

;; Register a skill
(define-public (register-skill (skill-name (string-ascii 100)) (skill-category (string-ascii 50)) (proficiency-level uint)
                              (certification (string-ascii 200)) (availability-hours (string-ascii 100)) (contact-method (string-ascii 100)))
    (let (
        (skill-id (+ (var-get skill-counter) u1))
        (current-height stacks-block-height)
    )
        (asserts! (and (>= proficiency-level u1) (<= proficiency-level u5)) ERR-INVALID-STATUS)
        
        (map-set skills skill-id {
            id: skill-id,
            provider: tx-sender,
            skill-name: skill-name,
            skill-category: skill-category,
            proficiency-level: proficiency-level,
            certification: certification,
            availability-hours: availability-hours,
            contact-method: contact-method,
            active: true,
            volunteer-since: current-height,
            total-hours-volunteered: u0
        })
        
        ;; Update community member stats
        (let (
            (member-info (default-to {member-since: current-height, resources-shared: u0, skills-offered: u0,
                                     reliability-score: u5, contact-preference: "phone", availability-status: u1}
                                    (map-get? community-members tx-sender)))
        )
            (map-set community-members tx-sender (merge member-info {
                skills-offered: (+ (get skills-offered member-info) u1)
            }))
        )
        
        (var-set skill-counter skill-id)
        (ok skill-id)
    )
)

;; Reserve a resource
(define-public (reserve-resource (resource-id uint) (quantity uint) (duration-hours uint) (purpose (string-ascii 200)))
    (let (
        (resource (unwrap! (map-get? resources resource-id) ERR-RESOURCE-NOT-FOUND))
        (current-height stacks-block-height)
        (expiry-time (+ current-height duration-hours))
    )
        (asserts! (is-eq (get status resource) STATUS-AVAILABLE) ERR-RESOURCE-UNAVAILABLE)
        (asserts! (>= (get quantity-available resource) quantity) ERR-INVALID-QUANTITY)
        
        ;; Create reservation
        (map-set reservations {resource-id: resource-id, requester: tx-sender} {
            quantity-reserved: quantity,
            reserved-at: current-height,
            expires-at: expiry-time,
            purpose: purpose,
            status: STATUS-RESERVED
        })
        
        ;; Update resource availability
        (map-set resources resource-id (merge resource {
            quantity-available: (- (get quantity-available resource) quantity),
            status: (if (is-eq (- (get quantity-available resource) quantity) u0) STATUS-RESERVED STATUS-AVAILABLE),
            last-updated: current-height
        }))
        
        (ok true)
    )
)

;; Update resource status
(define-public (update-resource-status (resource-id uint) (new-status uint))
    (let (
        (resource (unwrap! (map-get? resources resource-id) ERR-RESOURCE-NOT-FOUND))
    )
        (asserts! (or (is-eq tx-sender (get owner resource)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        (asserts! (and (>= new-status STATUS-AVAILABLE) (<= new-status STATUS-RETIRED)) ERR-INVALID-STATUS)
        
        (map-set resources resource-id (merge resource {
            status: new-status,
            last-updated: stacks-block-height
        }))
        
        (ok true)
    )
)

;; Update resource quantity
(define-public (update-resource-quantity (resource-id uint) (new-quantity uint))
    (let (
        (resource (unwrap! (map-get? resources resource-id) ERR-RESOURCE-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get owner resource)) ERR-UNAUTHORIZED)
        
        (map-set resources resource-id (merge resource {
            quantity-available: new-quantity,
            quantity-total: (if (> new-quantity (get quantity-total resource)) new-quantity (get quantity-total resource)),
            last-updated: stacks-block-height
        }))
        
        (ok true)
    )
)

;; Assign skill to incident
(define-public (assign-skill (skill-id uint) (incident-id uint) (estimated-hours uint) (notes (string-ascii 300)))
    (let (
        (skill (unwrap! (map-get? skills skill-id) ERR-SKILL-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (or (is-eq tx-sender (get provider skill)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get active skill) true) ERR-INVALID-STATUS)
        
        (map-set skill-assignments {skill-id: skill-id, incident-id: incident-id} {
            assigned-at: current-height,
            estimated-hours: estimated-hours,
            actual-hours: u0,
            status: STATUS-RESERVED,
            notes: notes
        })
        
        (ok true)
    )
)

;; Complete skill assignment
(define-public (complete-skill-assignment (skill-id uint) (incident-id uint) (actual-hours uint))
    (let (
        (assignment (unwrap! (map-get? skill-assignments {skill-id: skill-id, incident-id: incident-id}) ERR-SKILL-NOT-FOUND))
        (skill (unwrap! (map-get? skills skill-id) ERR-SKILL-NOT-FOUND))
    )
        (asserts! (or (is-eq tx-sender (get provider skill)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        
        ;; Update assignment
        (map-set skill-assignments {skill-id: skill-id, incident-id: incident-id} (merge assignment {
            actual-hours: actual-hours,
            status: STATUS-AVAILABLE
        }))
        
        ;; Update skill provider hours
        (map-set skills skill-id (merge skill {
            total-hours-volunteered: (+ (get total-hours-volunteered skill) actual-hours)
        }))
        
        (ok true)
    )
)

;; Add resource category
(define-public (add-resource-category (category-name (string-ascii 100)) (description (string-ascii 300)) (critical-threshold uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        
        (map-set resource-categories category-name {
            category-name: category-name,
            description: description,
            critical-threshold: critical-threshold,
            active: true
        })
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-resource (resource-id uint))
    (map-get? resources resource-id)
)

(define-read-only (get-skill (skill-id uint))
    (map-get? skills skill-id)
)

(define-read-only (get-reservation (resource-id uint) (requester principal))
    (map-get? reservations {resource-id: resource-id, requester: requester})
)

(define-read-only (get-skill-assignment (skill-id uint) (incident-id uint))
    (map-get? skill-assignments {skill-id: skill-id, incident-id: incident-id})
)

(define-read-only (get-resource-category (category-name (string-ascii 100)))
    (map-get? resource-categories category-name)
)

(define-read-only (get-community-member (member principal))
    (map-get? community-members member)
)

(define-read-only (get-resource-count)
    (var-get resource-counter)
)

(define-read-only (get-skill-count)
    (var-get skill-counter)
)

(define-read-only (get-admin)
    (var-get admin)
)

;; Check resource availability
(define-read-only (is-resource-available (resource-id uint) (required-quantity uint))
    (match (map-get? resources resource-id)
        resource (and (is-eq (get status resource) STATUS-AVAILABLE) 
                     (>= (get quantity-available resource) required-quantity))
        false
    )
)
