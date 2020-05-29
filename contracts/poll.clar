;; A very simple poll smart contract which allows to define and
;; start a poll and to vote for the options. Each vote can be 
;; registered only once and only the creator of the poll can stop it.

;; represents the poll using compund key of user and an option
(define-map poll ((user principal) (option int)) ((description (buff 100)) (votes int)))

;; map to hold auxiliary information on user's poll
;; option-counter servers only to distinguish options as they are added
;; only 100 unique voters can be set
(define-map poll-info ((user principal)) ((started? bool) (option-counter int) (voters (list 100 principal))))

;; error codes
(define-constant poll-started 1)
(define-constant poll-without-options 2)
(define-constant vote-invalid 3) ;; option does not exist
(define-constant poll-not-started 4) ;; poll did not start yet or wasn't found for specified address
(define-constant already-voted 5)
(define-constant max-voters-reached 6)

;; adds option, but does not allow to add it once poll started
(define-public (add-option (descr (buff 100)))
    (if (default-to false (get started? (map-get? poll-info ((user tx-sender)))))
        (err poll-started)
        ;; increment option-counter and save the option for current user
        (let ((counter (default-to 1 (get option-counter (map-get? poll-info ((user tx-sender)))))))
            (map-insert poll ((user tx-sender) (option counter)) ((description descr) (votes 0)))
            (ok (map-set poll-info ((user tx-sender)) ((started? false) (option-counter (+ counter 1)) (voters (list))))))))

;; starts the poll for current user and allows to vote for the options
(define-public (start-poll)
    (let ((counter (default-to 0 (get option-counter (map-get? poll-info ((user tx-sender)))))))
        ;; only allow to start the poll when there are at least two options
        (if (>= counter 2)
            (ok (map-set poll-info ((user tx-sender)) ((started? true) (option-counter counter) (voters (list)))))
            (err poll-without-options))))

;; auxiliary function
(define-private (equals-tx-sender? (user principal))
    (is-eq user tx-sender))

;; aux. fun.: checks whether a list contains tx-sender principal
(define-private (has-tx-sender? (lst (list 100 principal)))
    (is-eq u1 (len (filter equals-tx-sender? lst))))

;; voting function with address pointing to user who created the poll and number being the option number
(define-public (vote (address principal) (number int))
    (let ((val (map-get? poll ((user address) (option number))))
            (info (map-get? poll-info ((user address)))))
        ;; only allow to vote when the poll started 
        (if (not (default-to false (get started? info)))
            (err poll-not-started)
            ;; poll entry in map was not found, so the option number is invalid
            (if (is-none val)
                (err vote-invalid)
                ;; check whether current user is not already on the list of voters
                (if (has-tx-sender? (default-to (list) (get voters info)))
                    (err already-voted)
                    (ok (write-vote address number)))))))

;; auxiliary function to add the vote to total amount and register voter
(define-private (write-vote (address principal) (number int))
    (let ((val (map-get? poll ((user address) (option number))))
        (info (map-get? poll-info ((user address)))))
        (let ((descr (default-to "" (get description val)))
            (current-votes (default-to 0 (get votes val)))
            (counter (default-to 0 (get option-counter info)))
            (voters-list (as-max-len? (concat  (default-to (list) (get voters info)) (list tx-sender)) u100)))
            ;; we can only allow max 100 voters
            (if (is-none voters-list)
                (err max-voters-reached)
                (begin 
                    (map-set poll-info ((user address)) ((started? true) (option-counter counter) (voters (default-to (list) voters-list))))
                    (ok (map-set poll ((user address) (option number)) ((description descr) (votes (+ current-votes 1))))))))))

;; gets the result of the poll only one option at the time
;; it is expected that users know the options count
(define-public (get-result (address principal) (number int))
    (ok (default-to 0 (get votes (map-get? poll ((user address) (option number)))))))

;; ends the poll forbidding any more votes
(define-public (end-poll)
    ;; can obly be called when poll is active
    (if (default-to false (get started? (map-get? poll-info ((user tx-sender)))))
        (ok (map-set poll-info ((user tx-sender)) ((started? false) (option-counter 1) (voters (list)))))
        (err poll-not-started)))