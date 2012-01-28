;;; revive+.el --- Selected window memoization for revive
;;
;; Filename: revive+.el
;; Description: Selected window memoization for revive
;; Author: Martial Boniou
;; Maintainer: Martial Boniou
;; Created: Thu Mar 10 12:12:09 2011 (+0100)
;; Version: 0.9
;; Last-Updated: Sat Nov 26 18:16:23 2011 (+0100)
;;           By: Martial Boniou
;;     Update #: 173
;; URL: https://github.com/martialboniou/revive-plus.git
;; Keywords: window configuration serialization
;; Compatibility:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;              Let revive preserve the window focus to restore
;;              Support frames restoring in the printable window configuration
;;              Support escreen restoring in the printable window configuration
;;              Support special case like `ecb'
;;
;;              The window configuration has the following form:
;;              * for windows: ( WIDTH HEIGHT ... ) and so on (the same as in `revive'
;;              * for frames: ( ( WIDTH1 HEIGHT1 ... ) ( WIDTH2 HEIGHT2 ...) ... )
;;              * for escreen: ( POS ( WIDTH1 HEIGHT1 ... ) ( WIDTH2 HEIGHT2 ... ) )
;;              ie. the current escreen in this frame followed by the order printable
;;              window configuration for all the escreens: eg. ( 1 (WCONF0) (WCONF1)
;;              (WCONF2) )
;;              * for escreened frames: ( ( POS1 ( WIDTH1 ... ) ( WIDTH1' ... ) ... )
;;                                        ( POS2 ( WIDTH2 ... ) ( WIDTH2' ... ) ... )
;;                                        ... )
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Installation:
;;               (require 'revive+)
;;               (revive-plus:demo)
;;
;;  You may customize revive-plus:all-frames to save all frames:
;;
;;               (require 'revive+)
;;               (setq revive-plus:all-frames t)
;;               (revive-plus:demo)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Usage:
;;
;;        After calling (revive-plus:demo) or (revive-plus:minimal-setup),
;;        your window configuration is automatically saved on Emacs killing
;;        and restore at Emacs startup. The file ~/.emacs.d/last-wconf is
;;        used for this. If you want to prevent crashes by periodically
;;        autosave the latest window configuration you just need to ensure
;;        DESKTOP is autosaved:
;;
;;        (add-hook 'auto-save-hook #'(lambda () (call-interactively #'desktop-save)))
;;
;;        Remember: there are two functions to save window configurations:
;;
;;        #'CURRENT-WINDOW-CONFIGURATION-PRINTABLE : save the windows only (used by
;;                                                   <f6> keys in DEMO mode)
;;        #'WINDOW-CONFIGURATION-PRINTABLE : save the windows for all escreens and,
;;        if REVIVE-PLUS:ALL-FRAMES is set to true, in all frames too.
;;
;;        If REVIVE-PLUS:ALL-FRAMES is NIL and `escreen' is not enabled in your
;;        init file (~/.emacs), those two functions behave the same.
;;
;;        Additional functions are available:
;;        <f6><f6>: save the current window configuration (no frames / no escreen,
;;                  only the displayed windows in the current frame)
;;        <f6><f5>: restore the previously saved configuration
;;        <f6>2 .. <f6>0: restore the second to tenth window configuration
;;        All the last ten window configurations saved via <f6> keys are stored
;;        in the file ~/.emacs.d/wconf-archive and will be loaded at Emacs startup.
;;        This functionality is useful to transfer a window configuration to another
;;        frame, for example.
;;
;;        <f5><f5>: switch from a window configuration with multiple windows
;;                  to a single view and back. Useful to focus on a buffer.
;;        This functionality uses the standard window configuration system b/c
;;        there's no need to save it between sessions. The marker position is
;;        not saved; it's only the window configuration.
;;
;;        Beware: If you use Emacs in NO-WINDOW-SYSTEM (ie. in a terminal), you
;;                lose the window configuration in the other frames than the
;;                last focused one. If `escreen' is enabled, all the content of
;;                those other frames is restored as new ESCREEN. Eg.:
;;
;;                WINDOW-SYSTEM (saving):
;;
;;                -------------     -------------     -----------
;;                |  frame 2  |     |  frame 1  |     | frame 3 |
;;                |           |  +  |           |  +  |         |
;;                | ( 0 1 2 ) |     | ( 0 1 2 ) |     | ( 0 1 ) |
;;                -------------     -------------     -----------
;;
;;                where frame 1 is the focused one and ( X Y )s are the ESCREENs.
;;
;;                NO-WINDOW-SYSTEM (restoring):
;;
;;                -----------------------        /   ( 0 1 2 ) <= ( 0 1 2 ) in frame 1
;;                |     * no-frame *    |        |
;;                |                     | where  |   ( 4 5 6 ) <= ( 0 1 2 ) in frame 2
;;                | ( 0 1 2 4 5 6 7 8 ) |        |
;;                -----------------------        \   ( 7 8 )   <= ( 0 1 ) in frame 3
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:


(require 'revive)

(defconst revive-plus:version
  "revive+.el,v 0.9 <hondana@gmx.com>"
  "Version of revive+.el")

(defgroup revive-plus nil
  " Revive window configurations anywhere."
  :group 'convenience)

(defcustom revive-plus:all-frames nil
  "Revive all frames and their window-configurations.
If NIL, saving and restoring will be enabled for the currently
focused frame."
  :group 'revive-plus
  :type 'boolean)

(defcustom revive-plus:wconf-archive-file
  "~/.emacs.d/wconf-archive"
  "*File name where window configurations are saved to and loaded from."
  :type 'file
  :group 'revive-plus)

(defcustom revive-plus:wconf-archive-limit 10
  "Number of slots in the REVIVE-PLUS:WCONF-ARCHIVE register."
  :type 'integer
  :group 'revive-plus)

(defcustom revive-plus:last-wconf-file
  "~/.emacs.d/last-wconf"
  "File name where the last window configuration is saved. Useful to restore
the last session window configuration (s) at startup."
  :type 'file
  :group 'revive-plus)

(defvar revive-plus:previous-window-configuration nil
  "State of window configuration to restore. Used by
`revive-plus:toggle-single-window'.")

(defvar revive-plus:ecb-previously-running nil
  "Previous state of ECB.")

(defvar revive-plus:wconf-archive nil
  "A list of REVIVE-PLUS:WCONF-ARCHIVE-LIMIT printable window configurations.")

(defun revive:window-list (&optional frame)
  "Return the all window list in sorted order."
  (let*((curwin (if (null frame)
                    (selected-window)
                  (frame-selected-window frame)))
        (win curwin) wlist)
    (if (null
     (catch 'found
       (while t
         (if (and (= (revive:minx) (car (revive:window-edges win)))
              (= (revive:miny) (car (cdr (revive:window-edges win)))))
         (throw 'found t))
         (if (eq (setq win (next-window win)) curwin)
         (throw 'found nil)))))
    (error "Unexpected window configuration."))
    (setq curwin win wlist (list win))
    (while (not (eq curwin (setq win (next-window win))))
      (setq wlist (append wlist (list win)))) ;use append to preserve order
    wlist))

(defun revive:window-buffer-list (&optional frame)
  "Return the all shown buffer list.
Each element consists of '(buffer-file-name window-start point)"
  (let ((curw (if (null frame)
                  (selected-window)
                (frame-selected-window frame)))
        (wlist (revive:window-list)) wblist)
    (save-excursion
      (while wlist
    (select-window (car wlist))
    (set-buffer (window-buffer (car wlist))) ;for Emacs 19
    (setq wblist
          (append wblist
              (list (list
                 (if (and (fboundp 'abbreviate-file-name)
                      (buffer-file-name))
                 (abbreviate-file-name (buffer-file-name))
                   (buffer-file-name))
                 (window-start)
                 (point))))
          wlist (cdr wlist)))
      (select-window curw)
      wblist)))

(defun revive:select-window-by-edge (x y &optional frame)
  "Select window whose north west corner is (X, Y).
If the matching window is not found, select the nearest window."
  (let*((curwin (if (null frame)
                    (selected-window)
                  (frame-selected-window frame)))
        (win (next-window curwin)) edges
    s2 (min 99999) minwin)
    (or
     (catch 'found
       (while t
     (setq edges (revive:window-edges win)
           s2 (+ (* (- (car edges) x) (- (car edges) x))
             (* (- (nth 1 edges) y) (- (nth 1 edges) y))))
     (cond
      ((= s2 0)
       (select-window win)
       (throw 'found t))
      ((< s2 min)
       (setq min s2 minwin win)))
     (if (eq win curwin) (throw 'found nil)) ;select the nearest window
     (setq win (next-window win))))
     (select-window minwin))))

(defun revive:all-window-edges (&optional frame)
  "Return the all windows edges by list."
  (let ((wlist (revive:window-list frame)) edges)
    (while wlist
      (setq edges (append edges (list (revive:window-edges (car wlist))))
        wlist (cdr wlist)))
    edges))

(defun current-window-configuration-printable (&optional single-frame)
  "Print window configuration for a frame. Override the same
function defined in `revive'."
  (let ((curwin (if (or (null single-frame) (not (framep single-frame)))
                    (selected-window)
                  (frame-selected-window single-frame)))
        (wlist (revive:window-list single-frame))
        (edges (revive:all-window-edges single-frame)) buflist)
    (save-excursion
      (while wlist
        (select-window (car wlist))
                                        ;should set buffer on Emacs 19
        (set-buffer (window-buffer (car wlist)))
        (let ((buf (list
                    (if (and
                         (buffer-file-name)
                         (fboundp 'abbreviate-file-name))
                        (abbreviate-file-name
                         (buffer-file-name))
                      (buffer-file-name))
                    (buffer-name)
                    (point)
                    (window-start))))
          (when (eq curwin (selected-window))
            (setq buf (append buf (list nil 'focus))))
          (setq buflist
                (append buflist (list buf))))
        (setq wlist (cdr wlist)))
      (select-window curwin)
      (list (revive:screen-width) (revive:screen-height) edges buflist))))

(defun window-configuration-printable ()
  "Print window configuration for the current frame.
If REVIVE-PLUS:ALL-FRAMES is true, print window configuration for
all frames as a list of current-window-configuration-printable."
  (if (null revive-plus:all-frames)
      (current-window-configuration-printable)
    (let ((focus (selected-frame)))
      (mapcar #'(lambda (frame)
                  (current-window-configuration-printable frame))
               (cons focus (remq focus (frame-list)))))))

(defun restore-window-configuration (config)
  (if (listp (car config))              ; multiple frame case
      (progn
        (if (window-system)
            (progn
              (unless (null (cdr (frame-list)))
                (delete-other-frames))
              (restore-window-configuration (car config))
              (unless (null (cdr config))
                (mapc #'(lambda (cframe)
                          (make-frame)
                          (restore-window-configuration cframe))
                      (cdr config))
                (next-frame)))
          (restore-window-configuration (car config)))) ; lose other frames
                                        ; in NO-WINDOW-SYSTEM context
    (let ((width (car config)) (height (nth 1 config))
          (edges (nth 2 config)) (buflist (nth 3 config)) buf)
      (set-buffer (get-buffer-create "*scratch*"))
      (setq edges (revive:normalize-edges width height edges))
      (construct-window-configuration edges)
      (revive:select-window-by-edge (revive:minx) (revive:miny))
      (let (focus)
        (while buflist
          (setq buf (pop buflist))
          (cond
           ((and (revive:get-buffer buf)
                 (get-buffer (revive:get-buffer buf)))
            (switch-to-buffer (revive:get-buffer buf))
            (when (eq 'focus (car (last buf)))
              (setq focus (selected-window)))
            (goto-char (revive:get-window-start buf)) ; to prevent high-bit missing
            (set-window-start nil (point))
            (goto-char (revive:get-point buf)))
           ((and (stringp (revive:get-file buf))
                 (not (file-directory-p (revive:get-file buf)))
                 (revive:find-file (revive:get-file buf)))
            (set-window-start nil (revive:get-window-start buf))
            (goto-char (revive:get-point buf))))
          (other-window 1))
        (when focus
          (select-window focus))))))

(eval-after-load "escreen"
  '(progn
     (defun revive-plus:frame-to-escreen (wconf)
       "Convert frames in window configuration printable WCONF to
escreen."
       (let ((new-form (cons (caar wconf) (cdar wconf))))
         (mapc #'(lambda (w)
                   (nconc new-form (cdr w)))
               (cdr wconf))
         new-form))

     (defun current-window-configuration-printable (&optional single-frame)
       "Print escreen configuration for a frame."
       (save-excursion
         (save-window-excursion
           (unless single-frame (setq single-frame (selected-frame)))
           (let ((confs (mapcar 
                         #'(lambda (num)
                             (let ((data (escreen-configuration-escreen num)))
                               (escreen-save-current-screen-configuration) ; ensure to refresh screen to avoid broken map
                               (escreen-restore-screen-map data))
                             (let ((curwin (frame-selected-window single-frame)))
                               (let ((wlist (revive:window-list single-frame))
                                     (edges (revive:all-window-edges single-frame)) buflist)
                                 (while wlist
                                   (select-window (car wlist))
                                        ;should set buffer on Emacs 19
                                   (set-buffer (window-buffer (car wlist)))
                                   (let ((buf (list
                                               (if (and
                                                    (buffer-file-name)
                                                    (fboundp 'abbreviate-file-name))
                                                   (abbreviate-file-name
                                                    (buffer-file-name))
                                                 (buffer-file-name))
                                               (buffer-name)
                                               (point)
                                               (window-start))))
                                     (when (eq curwin (selected-window))
                                       (setq buf (append buf (list nil 'focus))))
                                     (setq buflist
                                           (append buflist (list buf))))
                                   (setq wlist (cdr wlist)))
                                 (select-window curwin)
                                 (list (revive:screen-width) (revive:screen-height) edges buflist))))
                         (if (and (boundp 'revive-plus:only-windows) ; FIXME: ugly / wconf-archive-save forgotten
                                  revive-plus:only-windows)
                             (list (escreen-get-current-screen-number))
                           (escreen-get-active-screen-numbers)))))
             (if (and (boundp 'revive-plus:only-windows)
                      revive-plus:only-windows)
                 confs
               (cons (escreen-get-current-screen-number) confs))))))

     (defadvice restore-window-configuration (around escreen-extension (config) activate)
       (if (listp (car config))         ; new multiple frame case
           (progn
             ;; enable persistency for NO-WINDOW-SYSTEM
             (unless (window-system)
               (restore-window-configuration
                (revive-plus:frame-to-escreen config)))
             (unless (null (cdr (frame-list)))
               (delete-other-frames))
             (restore-window-configuration (car config))
             (unless (null (cdr config))
               (mapc #'(lambda (cframe)
                         (make-frame)
                         (restore-window-configuration cframe))
                     (cdr config))
               (next-frame)))
         (if (listp (cadr config))      ; escreen case
             (progn
               (while (not (escreen-configuration-one-screen-p))
                 (escreen-kill-screen))      ; overkill existing escreens
               (restore-window-configuration (cadr config)) ; first escreen
               (mapc #'(lambda (cescreen)         ; others
                         (escreen-create-screen)
                         (restore-window-configuration cescreen))
                     (cddr config))
               (if (numberp (car config))    ; go to saved escreen
              (escreen-goto-screen (car config))))
           (progn
             ad-do-it))))))

;;;###autoload
(defun revive-plus:toggle-single-window ()
  "Toggle to single window and back. It uses standard
window configuration vector instead of REVIVE one as we
don't want to register the mark."
  (interactive)
  (if (cdr (window-list nil 0))
      (progn
        (setq revive-plus:previous-window-configuration
              (current-window-configuration))
        (delete-other-windows))
    (unless (null revive-plus:previous-window-configuration)
      (set-window-configuration revive-plus:previous-window-configuration))))

(defun revive-plus:wconf-archive-save (&optional dont-alert)
  (interactive)
  (when (or dont-alert (y-or-n-p "Archive the current window configuration? "))
    (setq revive-plus:wconf-archive (cons (let ((revive-plus:only-windows t))
                                            ;; ensure to get only windows (no ESCREENs by example)
                                            (current-window-configuration-printable))
                                          revive-plus:wconf-archive))
    (let ((out-num (- (length revive-plus:wconf-archive) revive-plus:wconf-archive-limit)))
      (nbutlast revive-plus:wconf-archive out-num))
    (unless (and (null revive-plus:wconf-archive)
                 (not (file-writable-p revive-plus:wconf-archive-file)))
      (with-temp-buffer
        (insert (prin1-to-string revive-plus:wconf-archive))
        (write-region (point-min) (point-max) revive-plus:wconf-archive-file)))))

;;;###autoload
(defun revive-plus:wconf-archive-clear ()
  (interactive)
  (when (yes-or-no-p "Delete the archived window configurations? ")
    (when (yes-or-no-p "Are you really sure? ")
      (setq revive-plus:wconf-archive nil)
      (condition-case nil
          (delete-file revive-plus:wconf-archive-file)
        (error
         (message "revive-plus: no window configuration archive file to delete"))))))

;;;###autoload
(defun revive-plus:wconf-archive-restore (&optional num)
  (interactive
   (if (and current-prefix-arg (not (consp current-prefix-arg)))
       (list (prefix-numeric-value current-prefix-arg))
     (list (read-number "Which window configuration number (0 is the last saved one): "))))
  (if (null revive-plus:wconf-archive)
      (message "revive-plus: no window configuration archived")
    (progn
      (when (or (not (integerp num))
                (< num 0))
        (setq num 0))
      (let ((wconf (if (>= num (length revive-plus:wconf-archive))
                       (last revive-plus:wconf-archive)
                     (nth num revive-plus:wconf-archive))))
        (unless (null wconf)
          (restore-window-configuration wconf))))))

(defun revive-plus:wconf-archive-load-in-session ()
  (when (and (file-exists-p revive-plus:wconf-archive-file)
             (file-readable-p revive-plus:wconf-archive-file))
    (with-temp-buffer
      (insert-file-contents revive-plus:wconf-archive-file)
      (setq revive-plus:wconf-archive (read (current-buffer))))))

;;;###autoload
(defun revive-plus:wconf-archive-load ()
  (interactive)
  (when (yes-or-no-p "Reload previous archived window configurations? ")
    (revive-plus:wconf-archive-load-in-session)))

;;;###autoload
(defun revive-plus:save-window-configuration (&optional special-case)
  (with-temp-buffer
    (insert (format "(restore-window-configuration '%s)" (prin1-to-string (window-configuration-printable))))
    (write-region (point-min) (point-max) revive-plus:last-wconf-file)))

;;;###autoload
(defun revive-plus:restore-window-configuration ()
  (let ((fi revive-plus:last-wconf-file))
    (when (file-exists-p fi)
      (load-file fi))))

(eval-after-load "ecb"
  '(progn
     (defun revive-plus:ecb-activated-in-this-frame ()
       (and (when (boundp 'ecb-activated-window-configuration)
              (not (null ecb-activated-window-configuration)))
            (eq (selected-frame)
                (when (boundp 'ecb-frame) ecb-frame))))

     (defadvice revive-plus:toggle-single-window (around ecb-active nil activate)
       (interactive)
       (if (cdr (window-list nil 0))
           (if (revive-plus:ecb-activated-in-this-frame)
               (when (y-or-n-p "This frame is ECB'd. Do you want to deactivate ECB? ")
                 (ecb-deactivate)
                 (setq revive-plus:ecb-previously-running t)
                 (delete-other-windows))
             (progn
               (setq revive-plus:previous-window-configuration
                     (current-window-configuration-printable))
               (setq revive-plus:ecb-previously-running nil)
               (delete-other-windows)))
         (if revive-plus:ecb-previously-running
             (progn
               (ecb-activate)
               (setq revive-plus:ecb-previously-running nil))
           (when revive-plus:previous-window-configuration
             (set-window-configuration revive-plus:previous-window-configuration)
             (setq revive-plus:ecb-previously-running nil)))))

     (defadvice revive-plus:save-window-configuration (around ecb-active (&optional special-case) activate)
       ;; you cannot deactivate ecb when desktop is autosaved so
       ;; `special-case' is here for the `kill-emacs-hook' case
       (let ((ecb-active (revive-plus:ecb-activated-in-this-frame)))
         (when (and special-case ecb-active)
           (ecb-deactivate))              
         (progn
           ad-do-it
           (when ecb-active
             (append-to-file "(ecb-activate)" nil revive-plus:last-wconf-file)))))

     (defadvice revive-plus:wconf-archive-save (around ecb-active nil activate)
       (interactive)
       (if (revive-plus:ecb-activated-in-this-frame)
           (when (y-or-n-p "BEWARE: you should deactivate ecb first. Archive the current window configuration anyway? ")
             (let ((dont-alert t))
               ad-do-it))
         ad-do-it))))

;;;###autoload
(defun revive-plus:start-wconf-archive (&optional with-keybindings)
  "Setup example for wconf-archive. Enable window configuration saving
and restoring for a single frame."
  (add-hook 'emacs-startup-hook
            #'revive-plus:wconf-archive-load-in-session)
  (when with-keybindings
    (global-set-key (kbd "<f6><f6>") #'revive-plus:wconf-archive-save)
    (global-set-key (kbd "<f6><f5>") #'(lambda () (interactive)
                                         (revive-plus:wconf-archive-restore 0)))
    (global-set-key (kbd "<f6>1") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 0)))
    (global-set-key (kbd "<f6>2") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 1)))
    (global-set-key (kbd "<f6>3") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 2)))
    (global-set-key (kbd "<f6>4") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 3)))
    (global-set-key (kbd "<f6>5") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 4)))
    (global-set-key (kbd "<f6>6") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 5)))
    (global-set-key (kbd "<f6>7") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 6)))
    (global-set-key (kbd "<f6>8") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 7)))
    (global-set-key (kbd "<f6>9") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 8)))
    (global-set-key (kbd "<f6>0") #'(lambda () (interactive)
                                      (revive-plus:wconf-archive-restore 9)))))

;;;###autoload
(defun revive-plus:start-last-wconf (&optional with-keybindings)
  "Setup example for last-wconf. Enable the complete window configuration
reload. Frame and Escreen are maintained if REVIVE-PLUS:ALL-FRAMES is true.
Frames are merged to escreen when Emacs is started in NO-WINDOW-SYSTEM context."
  (when (boundp 'desktop-save-hook)
    (add-hook 'desktop-save-hook
              ;; prevent crashes' loss if DESKTOP is autosaved
              #'revive-plus:save-window-configuration 'append))
  (add-hook 'kill-emacs-hook
            ;; force window configuration special case like `ecb' if any
            #'(lambda () (revive-plus:save-window-configuration t)) 'append)
  (add-hook 'after-init-hook #'revive-plus:restore-window-configuration 'append))

;;;###autoload
(defun revive-plus:demo ()
  "Setup example for revive-plus including wconf-archive, complete window
configuration reload and single window switching key."
  (global-set-key (kbd "<f5><f5>") #'revive-plus:toggle-single-window)
  (revive-plus:start-wconf-archive t)

  (revive-plus:start-last-wconf t))

;;;###autoload
(defun revive-plus:minimal-setup ()
  "Setup example for revive-plus. Like `revive-plus:demo', w/o key bindings."
  (revive-plus:start-wconf-archive)
  (revive-plus:start-last-wconf))

(provide 'revive+)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; revive+.el ends here
