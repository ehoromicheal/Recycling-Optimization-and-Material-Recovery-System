;; Circular Economy Contract
;; Tracks waste reduction initiatives and sustainability metrics

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INITIATIVE-NOT-FOUND (err u501))
(define-constant ERR-INVALID-METRIC (err u502))
(define-constant ERR-GOAL-NOT-FOUND (err u503))

;; Data Variables
(define-data-var next-initiative-id uint u1)
(define-data-var next-goal-id uint u1)
(define-data-var global-waste-reduction uint u0)

;; Data Maps
(define-map sustainability-initiatives
  { initiative-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    target-reduction: uint,
    current-reduction: uint,
    start-date: uint,
    end-date: uint,
    status: (string-ascii 20),
    coordinator: principal
  }
)

(define-map environmental-metrics
  { metric-id: uint }
  {
    metric-type: (string-ascii 50),
    value: uint,
    unit: (string-ascii 20),
    measurement-date: uint,
    verified: bool,
    reporter: principal
  }
)

(define-map waste-reduction-goals
  { goal-id: uint }
  {
    goal-type: (string-ascii 50),
    target-amount: uint,
    current-amount: uint,
    deadline: uint,
    priority: (string-ascii 10),
    achieved: bool
  }
)

(define-map impact-reports
  { report-id: uint }
  {
    reporting-period: uint,
    total-waste-diverted: uint,
    co2-reduction: uint,
    energy-saved: uint,
    water-saved: uint,
    report-date: uint,
    verified: bool
  }
)

(define-map circular-projects
  { project-id: uint }
  {
    project-name: (string-ascii 100),
    project-type: (string-ascii 50),
    materials-recovered: uint,
    economic-value: uint,
    environmental-benefit: uint,
    completion-status: uint,
    start-date: uint
  }
)

;; Read-only functions
(define-read-only (get-sustainability-initiative (initiative-id uint))
  (map-get? sustainability-initiatives { initiative-id: initiative-id })
)

(define-read-only (get-environmental-metric (metric-id uint))
  (map-get? environmental-metrics { metric-id: metric-id })
)

(define-read-only (get-waste-reduction-goal (goal-id uint))
  (map-get? waste-reduction-goals { goal-id: goal-id })
)

(define-read-only (get-impact-report (report-id uint))
  (map-get? impact-reports { report-id: report-id })
)

(define-read-only (get-circular-project (project-id uint))
  (map-get? circular-projects { project-id: project-id })
)

(define-read-only (get-global-waste-reduction)
  (var-get global-waste-reduction)
)

(define-read-only (calculate-initiative-progress (initiative-id uint))
  (match (get-sustainability-initiative initiative-id)
    initiative (let ((progress (if (> (get target-reduction initiative) u0)
      (/ (* (get current-reduction initiative) u100) (get target-reduction initiative))
      u0)))
      (ok progress)
    )
    ERR-INITIATIVE-NOT-FOUND
  )
)

;; Public functions
(define-public (create-sustainability-initiative (name (string-ascii 100)) (description (string-ascii 300)) (target-reduction uint) (end-date uint))
  (let ((initiative-id (var-get next-initiative-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set sustainability-initiatives
      { initiative-id: initiative-id }
      {
        name: name,
        description: description,
        target-reduction: target-reduction,
        current-reduction: u0,
        start-date: block-height,
        end-date: end-date,
        status: "active",
        coordinator: tx-sender
      }
    )

    (var-set next-initiative-id (+ initiative-id u1))
    (ok initiative-id)
  )
)

(define-public (update-initiative-progress (initiative-id uint) (additional-reduction uint))
  (let ((initiative (unwrap! (get-sustainability-initiative initiative-id) ERR-INITIATIVE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get coordinator initiative)) ERR-NOT-AUTHORIZED)

    (let ((new-reduction (+ (get current-reduction initiative) additional-reduction)))
      (map-set sustainability-initiatives
        { initiative-id: initiative-id }
        (merge initiative {
          current-reduction: new-reduction,
          status: (if (>= new-reduction (get target-reduction initiative)) "completed" "active")
        })
      )

      (var-set global-waste-reduction (+ (var-get global-waste-reduction) additional-reduction))
      (ok new-reduction)
    )
  )
)

(define-public (record-environmental-metric (metric-type (string-ascii 50)) (value uint) (unit (string-ascii 20)) (metric-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> value u0) ERR-INVALID-METRIC)

    (map-set environmental-metrics
      { metric-id: metric-id }
      {
        metric-type: metric-type,
        value: value,
        unit: unit,
        measurement-date: block-height,
        verified: false,
        reporter: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (set-waste-reduction-goal (goal-type (string-ascii 50)) (target-amount uint) (deadline uint) (priority (string-ascii 10)))
  (let ((goal-id (var-get next-goal-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set waste-reduction-goals
      { goal-id: goal-id }
      {
        goal-type: goal-type,
        target-amount: target-amount,
        current-amount: u0,
        deadline: deadline,
        priority: priority,
        achieved: false
      }
    )

    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

(define-public (update-goal-progress (goal-id uint) (progress-amount uint))
  (let ((goal (unwrap! (get-waste-reduction-goal goal-id) ERR-GOAL-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (let ((new-amount (+ (get current-amount goal) progress-amount)))
      (map-set waste-reduction-goals
        { goal-id: goal-id }
        (merge goal {
          current-amount: new-amount,
          achieved: (>= new-amount (get target-amount goal))
        })
      )
      (ok new-amount)
    )
  )
)

(define-public (submit-impact-report (report-id uint) (waste-diverted uint) (co2-reduction uint) (energy-saved uint) (water-saved uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set impact-reports
      { report-id: report-id }
      {
        reporting-period: block-height,
        total-waste-diverted: waste-diverted,
        co2-reduction: co2-reduction,
        energy-saved: energy-saved,
        water-saved: water-saved,
        report-date: block-height,
        verified: false
      }
    )
    (ok true)
  )
)

(define-public (create-circular-project (project-id uint) (project-name (string-ascii 100)) (project-type (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set circular-projects
      { project-id: project-id }
      {
        project-name: project-name,
        project-type: project-type,
        materials-recovered: u0,
        economic-value: u0,
        environmental-benefit: u0,
        completion-status: u0,
        start-date: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-project-metrics (project-id uint) (materials-recovered uint) (economic-value uint) (environmental-benefit uint))
  (let ((project (unwrap! (get-circular-project project-id) ERR-INITIATIVE-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set circular-projects
      { project-id: project-id }
      (merge project {
        materials-recovered: materials-recovered,
        economic-value: economic-value,
        environmental-benefit: environmental-benefit
      })
    )
    (ok true)
  )
)

(define-public (verify-environmental-metric (metric-id uint))
  (let ((metric (unwrap! (get-environmental-metric metric-id) ERR-INVALID-METRIC)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set environmental-metrics
      { metric-id: metric-id }
      (merge metric { verified: true })
    )
    (ok true)
  )
)

(define-public (verify-impact-report (report-id uint))
  (let ((report (unwrap! (get-impact-report report-id) ERR-INVALID-METRIC)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set impact-reports
      { report-id: report-id }
      (merge report { verified: true })
    )
    (ok true)
  )
)
