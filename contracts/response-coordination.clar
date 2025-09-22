;; Neighborhood Resilience Network - Response Coordination Contract
;; Coordinate community response during emergency situations

;; Data Variables
(define-data-var incident-counter uint u0)
(define-data-var response-team-counter uint u0)
(define-data-var admin principal tx-sender)

;; Constants
(define-constant ERR-UNAUTHORIZED (err u500))
(define-constant ERR-INCIDENT-NOT-FOUND (err u501))
(define-constant ERR-TEAM-NOT-FOUND (err u502))
(define-constant ERR-INVALID-STATUS (err u503))
(define-constant ERR-ALREADY-ASSIGNED (err u504))
(define-constant ERR-INVALID-SEVERITY (err u505))
(define-constant ERR-INCIDENT-CLOSED (err u506))

;; Incident Severity Levels
(define-constant SEVERITY-LOW u1)
(define-constant SEVERITY-MEDIUM u2)
(define-constant SEVERITY-HIGH u3)
(define-constant SEVERITY-CRITICAL u4)
(define-constant SEVERITY-DISASTER u5)

;; Incident Status
(define-constant STATUS-REPORTED u1)
(define-constant STATUS-CONFIRMED u2)
(define-constant STATUS-RESPONDING u3)
(define-constant STATUS-RESOLVED u4)
(define-constant STATUS-CLOSED u5)

;; Response Team Status
(define-constant TEAM-STATUS-FORMING u1)
(define-constant TEAM-STATUS-DEPLOYED u2)
(define-constant TEAM-STATUS-ACTIVE u3)
(define-constant TEAM-STATUS-RETURNING u4)
(define-constant TEAM-STATUS-DEBRIEFING u5)

;; Incident Data Structure
(define-map incidents uint {
    id: uint,
    reporter: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    incident-type: (string-ascii 50),
    severity-level: uint,
    status: uint,
    location: (string-ascii 200),
    coordinates: (string-ascii 50),
    affected-people: uint,
    resources-needed: (string-ascii 300),
    response-teams-assigned: uint,
    estimated-duration: uint,
    actual-duration: (optional uint),
    reported-at: uint,
    confirmed-at: (optional uint),
    resolved-at: (optional uint)
})

;; Response Team Data Structure
(define-map response-teams uint {
    id: uint,
    lead-coordinator: principal,
    team-name: (string-ascii 100),
    specialization: (string-ascii 100),
    team-size: uint,
    current-incident: (optional uint),
    status: uint,
    equipment-allocated: (string-ascii 300),
    deployment-location: (string-ascii 200),
    contact-frequency: uint,
    last-status-update: uint,
    created-at: uint
})

;; Team Member Assignments
(define-map team-members {team-id: uint, member: principal} {
    role: (string-ascii 50),
    skills: (string-ascii 200),
    assigned-at: uint,
    status: uint,
    contact-info: (string-ascii 100)
})

;; Incident Updates
(define-map incident-updates {incident-id: uint, update-id: uint} {
    update-id: uint,
    updater: principal,
    update-type: (string-ascii 50),
    message: (string-ascii 500),
    severity-change: (optional uint),
    resources-requested: (string-ascii 200),
    timestamp: uint
})

;; Resource Deployments
(define-map resource-deployments {incident-id: uint, resource-id: uint} {
    deployment-id: uint,
    deployed-by: principal,
    resource-type: (string-ascii 100),
    quantity-deployed: uint,
    deployment-location: (string-ascii 200),
    deployment-status: uint,
    deployed-at: uint,
    expected-return: (optional uint)
})

;; Communication Log
(define-map communication-log {incident-id: uint, log-id: uint} {
    log-id: uint,
    sender: principal,
    recipient-type: (string-ascii 50),
    message: (string-ascii 400),
    priority: uint,
    acknowledged: bool,
    timestamp: uint
})

;; Report an incident
(define-public (report-incident (title (string-ascii 100)) (description (string-ascii 500)) (incident-type (string-ascii 50))
                               (severity-level uint) (location (string-ascii 200)) (coordinates (string-ascii 50))
                               (affected-people uint) (resources-needed (string-ascii 300)))
    (let (
        (incident-id (+ (var-get incident-counter) u1))
        (current-height stacks-block-height)
    )
        (asserts! (and (>= severity-level SEVERITY-LOW) (<= severity-level SEVERITY-DISASTER)) ERR-INVALID-SEVERITY)
        
        (map-set incidents incident-id {
            id: incident-id,
            reporter: tx-sender,
            title: title,
            description: description,
            incident-type: incident-type,
            severity-level: severity-level,
            status: STATUS-REPORTED,
            location: location,
            coordinates: coordinates,
            affected-people: affected-people,
            resources-needed: resources-needed,
            response-teams-assigned: u0,
            estimated-duration: u0,
            actual-duration: none,
            reported-at: current-height,
            confirmed-at: none,
            resolved-at: none
        })
        
        (var-set incident-counter incident-id)
        (ok incident-id)
    )
)

;; Confirm incident
(define-public (confirm-incident (incident-id uint) (estimated-duration uint))
    (let (
        (incident (unwrap! (map-get? incidents incident-id) ERR-INCIDENT-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status incident) STATUS-REPORTED) ERR-INVALID-STATUS)
        
        (map-set incidents incident-id (merge incident {
            status: STATUS-CONFIRMED,
            estimated-duration: estimated-duration,
            confirmed-at: (some current-height)
        }))
        
        (ok true)
    )
)

;; Create response team
(define-public (create-response-team (team-name (string-ascii 100)) (specialization (string-ascii 100)) (equipment-allocated (string-ascii 300)))
    (let (
        (team-id (+ (var-get response-team-counter) u1))
        (current-height stacks-block-height)
    )
        (map-set response-teams team-id {
            id: team-id,
            lead-coordinator: tx-sender,
            team-name: team-name,
            specialization: specialization,
            team-size: u1,
            current-incident: none,
            status: TEAM-STATUS-FORMING,
            equipment-allocated: equipment-allocated,
            deployment-location: "",
            contact-frequency: u30,
            last-status-update: current-height,
            created-at: current-height
        })
        
        ;; Add creator as team member
        (map-set team-members {team-id: team-id, member: tx-sender} {
            role: "Lead Coordinator",
            skills: specialization,
            assigned-at: current-height,
            status: u1,
            contact-info: ""
        })
        
        (var-set response-team-counter team-id)
        (ok team-id)
    )
)

;; Assign team to incident
(define-public (assign-team-to-incident (team-id uint) (incident-id uint) (deployment-location (string-ascii 200)))
    (let (
        (team (unwrap! (map-get? response-teams team-id) ERR-TEAM-NOT-FOUND))
        (incident (unwrap! (map-get? incidents incident-id) ERR-INCIDENT-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (or (is-eq tx-sender (get lead-coordinator team)) (is-eq tx-sender (var-get admin))) ERR-UNAUTHORIZED)
        (asserts! (is-none (get current-incident team)) ERR-ALREADY-ASSIGNED)
        (asserts! (>= (get status incident) STATUS-CONFIRMED) ERR-INVALID-STATUS)
        
        ;; Update team assignment
        (map-set response-teams team-id (merge team {
            current-incident: (some incident-id),
            status: TEAM-STATUS-DEPLOYED,
            deployment-location: deployment-location,
            last-status-update: current-height
        }))
        
        ;; Update incident
        (map-set incidents incident-id (merge incident {
            status: STATUS-RESPONDING,
            response-teams-assigned: (+ (get response-teams-assigned incident) u1)
        }))
        
        (ok true)
    )
)

;; Add team member
(define-public (add-team-member (team-id uint) (member principal) (role (string-ascii 50)) (skills (string-ascii 200)) (contact-info (string-ascii 100)))
    (let (
        (team (unwrap! (map-get? response-teams team-id) ERR-TEAM-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (is-eq tx-sender (get lead-coordinator team)) ERR-UNAUTHORIZED)
        
        (map-set team-members {team-id: team-id, member: member} {
            role: role,
            skills: skills,
            assigned-at: current-height,
            status: u1,
            contact-info: contact-info
        })
        
        ;; Update team size
        (map-set response-teams team-id (merge team {
            team-size: (+ (get team-size team) u1),
            last-status-update: current-height
        }))
        
        (ok true)
    )
)

;; Update incident status
(define-public (update-incident-status (incident-id uint) (new-status uint) (update-message (string-ascii 500)))
    (let (
        (incident (unwrap! (map-get? incidents incident-id) ERR-INCIDENT-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
        (asserts! (and (>= new-status STATUS-REPORTED) (<= new-status STATUS-CLOSED)) ERR-INVALID-STATUS)
        
        (map-set incidents incident-id (merge incident {
            status: new-status,
            resolved-at: (if (is-eq new-status STATUS-RESOLVED) (some current-height) (get resolved-at incident))
        }))
        
        ;; Log the update
        (map-set incident-updates {incident-id: incident-id, update-id: current-height} {
            update-id: current-height,
            updater: tx-sender,
            update-type: "status-change",
            message: update-message,
            severity-change: none,
            resources-requested: "",
            timestamp: current-height
        })
        
        (ok true)
    )
)

;; Deploy resource to incident
(define-public (deploy-resource (incident-id uint) (resource-id uint) (resource-type (string-ascii 100))
                               (quantity uint) (deployment-location (string-ascii 200)))
    (let (
        (incident (unwrap! (map-get? incidents incident-id) ERR-INCIDENT-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (get reporter incident))) ERR-UNAUTHORIZED)
        (asserts! (< (get status incident) STATUS-CLOSED) ERR-INCIDENT-CLOSED)
        
        (map-set resource-deployments {incident-id: incident-id, resource-id: resource-id} {
            deployment-id: current-height,
            deployed-by: tx-sender,
            resource-type: resource-type,
            quantity-deployed: quantity,
            deployment-location: deployment-location,
            deployment-status: u1,
            deployed-at: current-height,
            expected-return: none
        })
        
        (ok true)
    )
)

;; Send communication
(define-public (send-communication (incident-id uint) (recipient-type (string-ascii 50)) (message (string-ascii 400)) (priority uint))
    (let (
        (incident (unwrap! (map-get? incidents incident-id) ERR-INCIDENT-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (< (get status incident) STATUS-CLOSED) ERR-INCIDENT-CLOSED)
        (asserts! (and (>= priority u1) (<= priority u5)) ERR-INVALID-SEVERITY)
        
        (map-set communication-log {incident-id: incident-id, log-id: current-height} {
            log-id: current-height,
            sender: tx-sender,
            recipient-type: recipient-type,
            message: message,
            priority: priority,
            acknowledged: false,
            timestamp: current-height
        })
        
        (ok true)
    )
)

;; Update team status
(define-public (update-team-status (team-id uint) (new-status uint) (status-message (string-ascii 300)))
    (let (
        (team (unwrap! (map-get? response-teams team-id) ERR-TEAM-NOT-FOUND))
        (current-height stacks-block-height)
    )
        (asserts! (is-eq tx-sender (get lead-coordinator team)) ERR-UNAUTHORIZED)
        (asserts! (and (>= new-status TEAM-STATUS-FORMING) (<= new-status TEAM-STATUS-DEBRIEFING)) ERR-INVALID-STATUS)
        
        (map-set response-teams team-id (merge team {
            status: new-status,
            last-status-update: current-height
        }))
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-incident (incident-id uint))
    (map-get? incidents incident-id)
)

(define-read-only (get-response-team (team-id uint))
    (map-get? response-teams team-id)
)

(define-read-only (get-team-member (team-id uint) (member principal))
    (map-get? team-members {team-id: team-id, member: member})
)

(define-read-only (get-incident-update (incident-id uint) (update-id uint))
    (map-get? incident-updates {incident-id: incident-id, update-id: update-id})
)

(define-read-only (get-resource-deployment (incident-id uint) (resource-id uint))
    (map-get? resource-deployments {incident-id: incident-id, resource-id: resource-id})
)

(define-read-only (get-communication (incident-id uint) (log-id uint))
    (map-get? communication-log {incident-id: incident-id, log-id: log-id})
)

(define-read-only (get-incident-count)
    (var-get incident-counter)
)

(define-read-only (get-team-count)
    (var-get response-team-counter)
)

(define-read-only (get-admin)
    (var-get admin)
)

;; Check if incident is active
(define-read-only (is-incident-active (incident-id uint))
    (match (map-get? incidents incident-id)
        incident (and (>= (get status incident) STATUS-CONFIRMED) (< (get status incident) STATUS-CLOSED))
        false
    )
)
