(in-package #:trivial-backtrace)

(setf (documentation 'print-backtrace-to-stream 'function)
  "Send a backtrace of the current error to stream. 

Stream is assumed to be an open writable file stream or a
string-output-stream. Note that `print-backtrace-to-stream`
will print a backtrace for whatever the Lisp deems to be the 
*current* error.
")

(defun print-backtrace (error &key (output nil) (if-exists :append)
			(verbose nil))
  "Send a backtrace for the error `error` to `output`. 

The keywords arguments are:

 * :output - where to send the output. This can be:

     * a string (which is assumed to designate a pathname)
     * an open stream
     * nil to indicate that the backtrace information should be 
       returned as a string

 * if-exists - what to do if output designates a pathname and 
   the pathname already exists. Defaults to :append.

 * verbose - if true, then a message about the backtrace is sent
   to \\*terminal-io\\*. Defaults to `nil`.

If the `output` is nil, the returns the backtrace output as a
string. Otherwise, returns nil.
"
  (when verbose
    (format
     *terminal-io*
     "~@<An unhandled error condition has been signalled:~3I ~a~I~:@>~%~%"
     error))
  (multiple-value-bind (output close?)
      (typecase output
	(null (values (make-string-output-stream) nil))
	(string (values (open output :if-exists if-exists
			      :if-does-not-exist :create
			      :direction :output) t))
	(stream (values output nil)))
    (unwind-protect
	 (progn
	   (print-backtrace-to-stream output)
	   (when (typep output 'string-stream)
	     (get-output-stream-string output)))
	 ;; cleanup
	 (when close?
	   (close output)))))

#+mcl
(defun print-backtrace-to-stream (stream)
  (let ((*debug-io* stream))
    (ccl:print-call-history :detailed-p nil)))

#+allegro
(defun print-backtrace-to-stream (stream)
  (with-standard-io-syntax
    (let ((*print-readably* nil)
	  (*print-miser-width* 40)
	  (*print-pretty* t)
	  (tpl:*zoom-print-circle* t)
	  (tpl:*zoom-print-level* nil)
	  (tpl:*zoom-print-length* nil))
      (cl:ignore-errors
       (let ((*terminal-io* stream)
	     (*standard-output* stream))
	 (tpl:do-command "zoom"
	   :from-read-eval-print-loop nil
	   :count t
	   :all t))))))

#+lispworks
(defun print-backtrace-to-stream (stream)
  (let ((dbg::*debugger-stack*
	 (dbg::grab-stack nil :how-many most-positive-fixnum))
	(*debug-io* stream)
	(dbg:*debug-print-level* nil)
	(dbg:*debug-print-length* nil))
    (dbg:bug-backtrace nil)))

#+sbcl
;; determine how we're going to access the backtrace in the next
;; function
(eval-when (:compile-toplevel :load-toplevel :execute)
  (when (find-symbol "*DEBUG-PRINT-VARIABLE-ALIST*" :sb-debug)
    (pushnew :hunchentoot-sbcl-debug-print-variable-alist *features*)))

#+sbcl
(defun print-backtrace-to-stream (stream)
  (let (#+:hunchentoot-sbcl-debug-print-variable-alist
	(sb-debug:*debug-print-variable-alist*
	 (list* '(*print-level* . nil)
		'(*print-length* . nil)
		sb-debug:*debug-print-variable-alist*))
	#-:hunchentoot-sbcl-debug-print-variable-alist
	(sb-debug:*debug-print-level* nil)
	#-:hunchentoot-sbcl-debug-print-variable-alist
	(sb-debug:*debug-print-length* nil))
    (sb-debug:backtrace most-positive-fixnum stream)))

#+clisp
(defun print-backtrace-to-stream (stream)
  (system::print-backtrace :out stream))

#+(or cmucl scl)
(defun print-backtrace-to-stream (stream)
  (let ((debug:*debug-print-level* nil)
	(debug:*debug-print-length* nil))
    (debug:backtrace most-positive-fixnum stream)))

