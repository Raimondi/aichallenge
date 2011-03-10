;;;; ants-bot.lisp

(in-package :ants-bot)


;;; Main Program

;; This MAIN is used on the competition server.
(defun main (&key (log nil) (state (make-instance 'state)) (verbose nil))
  (let ((*state* state)
        (*verbose* verbose))
    (cond ((and log *verbose*)
           (setf (slot-value *state* 'log-stream)
                 (open log :direction :output :if-exists :append
                           :if-does-not-exist :create)))
          (*verbose*
           (setf (slot-value *state* 'log-stream) *debug-io*)))
    (logmsg "~&=== New Match: " (current-date-time-string) " ===~%")
    (handler-bind ((sb-sys:interactive-interrupt #'interrupted-by-user))
      (loop while (handler-case (peek-char nil (input *state*) nil)
                    (sb-int:simple-stream-error nil))
            for end-of-game-p = (parse-game-state)
            when end-of-game-p do (loop-finish)
            do (logmsg "--- turn: " (turn *state*) " ---~%")
               (logmsg "~&[start] " (current-date-time-string) "~%")
               (bot-think)
               (end-of-turn)
               (logmsg "~&[  end] move took " (turn-time-used) " seconds ("
                       (turn-time-remaining) " left).~%")))))


;; This MAIN is called when you use the Makefile locally.
(defun main-for-local (&key (log "ants-bot.log") (verbose t))
  (main :log log :verbose verbose))


;; This MAIN is for the Slime REPL with bin/play-proxy-game.sh.
(defun main-for-proxybot (&key (log "ants-bot-proxied.log") (verbose t))
  (let (client socket stream)
    (handler-bind ((address-in-use-error #'address-in-use))
      (setf socket (socket-listen #-allegro #(127 0 0 1) #+allegro "localhost"
                                  41807 :reuse-address t))
      (format *debug-io* "Waiting for connection...~%")
      (force-output)
      (setf client (socket-accept socket)
            stream (socket-stream client))
      (format *debug-io* "Connected. Playing game...~%")
      (force-output))
    (unwind-protect
         (main :state (make-instance 'state :input stream :output stream)
               :log log :verbose verbose)
      (ignore-errors (socket-close client)  ; TODO actually test these
                     (socket-close socket))
      (format *debug-io* "Game finished. Connection closed...~%"))))
