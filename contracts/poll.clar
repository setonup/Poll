(define-map poll-info ((user principal)) ((started? bool) (option-counter int) (voters (list 100 principal))))
(define-map poll ((user principal) (option int)) ((description (buff 100)) (votes int)))

(define-constant poll-started 1)
(define-constant poll-without-options 2)
(define-constant vote-invalid 3) ;; option does not exist
(define-constant poll-not-started 4) ;; poll did not start yet or wasn't found for specified address
(define-constant already-voted 5)
(define-constant max-voters-reached 6)

(define-public (add-option (descr (buff 100)))
    (if (default-to false (get started? (map-get? poll-info ((user tx-sender)))))
        (err poll-started)
        (let ((counter (default-to 1 (get option-counter (map-get? poll-info ((user tx-sender)))))))
            (map-insert poll ((user tx-sender) (option counter)) ((description descr) (votes 0)))
            (ok (map-set poll-info ((user tx-sender)) ((started? false) (option-counter (+ counter 1)) (voters (list))))))))
    
(define-public (start-poll)
    (let ((counter (default-to 0 (get option-counter (map-get? poll-info ((user tx-sender)))))))
        (if (>= counter 2)
            (ok (map-set poll-info ((user tx-sender)) ((started? true) (option-counter counter) (voters (list)))))
            (err poll-without-options))))

(define-private (equals-tx-sender? (user principal))
    (is-eq user tx-sender))

(define-private (has-tx-sender? (lst (list 100 principal)))
    (is-eq u1 (len (filter equals-tx-sender? lst))))

(define-private (write-vote (address principal) (number int))
    (let ((val (map-get? poll ((user address) (option number))))
        (info (map-get? poll-info ((user address)))))
        (let ((descr (default-to "" (get description val)))
            (current-votes (default-to 0 (get votes val)))
            (counter (default-to 0 (get option-counter info)))
            (voters-list (as-max-len? (concat  (default-to (list) (get voters info)) (list tx-sender)) u100)))
            (if (is-none voters-list)
                (err max-voters-reached)
                (begin 
                    (map-set poll-info ((user address)) ((started? true) (option-counter counter) (voters (default-to (list) voters-list))))
                    (ok (map-set poll ((user address) (option number)) ((description descr) (votes (+ current-votes 1))))))))))

(define-public (vote (address principal) (number int))
    (let ((val (map-get? poll ((user address) (option number))))
            (info (map-get? poll-info ((user address)))))
        (if (not (default-to false (get started? info)))
            (err poll-not-started)
            (if (is-none val)
                (err vote-invalid)
                (if (has-tx-sender? (default-to (list) (get voters info)))
                    (err already-voted)
                    (ok (write-vote address number)))))))

(define-public (get-result (address principal) (number int))
    (ok (default-to 0 (get votes (map-get? poll ((user address) (option number)))))))

(define-public (end-poll)
    (if (default-to false (get started? (map-get? poll-info ((user tx-sender)))))
        (ok (map-set poll-info ((user tx-sender)) ((started? false) (option-counter 1) (voters (list)))))
        (err poll-not-started)))