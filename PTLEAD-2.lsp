;;;=========================================================================
;;; Command: PTLEAD
;;; Layer  : corninates (Color 3 - Green, auto-created)
;;; Style  : Uses active MLEADERSTYLE (CMLEADERSTYLE)
;;; Output : Coordinates annotated in METERS
;;; Note   : MLeader is built via ActiveX - NO command prompts, so it is
;;;          unaffected by Block-content / Content-first styles.
;;;=========================================================================
(defun c:PTLEAD (/ *error* oldEcho oldLayer pt1 pt2 strText targetLayer
                   unitFactor mPrec forceMText xM yM curStyle ml)
  (vl-load-com)

  (defun *error* (msg)
    (if oldEcho  (setvar "CMDECHO" oldEcho))
    (if oldLayer (setvar "CLAYER" oldLayer))
    (if (and msg (not (wcmatch (strcase msg t) "*break*,*cancel*,*exit*")))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  ;;--------------------------------------------------------------------
  ;; USER SETTINGS
  ;;--------------------------------------------------------------------
  (setq unitFactor 0.001)  ; drawing units -> meters
                           ;   mm = 0.001 | cm = 0.01 | m = 1.0
                           ;   ft = 0.3048 | in = 0.0254
  (setq mPrec      3)      ; decimal places shown for meters
  (setq forceMText T)      ; T = always force MText content on the leader,
                           ;     even if the current style is Block content.
                           ; nil = leave the style's own content type alone.
  (setq targetLayer "corninates")

  ;;--------------------------------------------------------------------
  ;; Build one MLEADER object directly - no command, no prompts
  ;;--------------------------------------------------------------------
  (defun PTL:MakeMLeader (p1 p2 txt lay sty force / spc arr obj r)
    (setq r
      (vl-catch-all-apply
        '(lambda ()
           (setq spc (vla-get-Block
                       (vla-get-ActiveLayout
                         (vla-get-ActiveDocument (vlax-get-acad-object)))))
           (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 5)))
           (vlax-safearray-fill arr
             (list (car p1) (cadr p1) 0.0
                   (car p2) (cadr p2) 0.0))
           ;; second argument is the (output) leader index - 0 is fine
           (setq obj (vla-AddMLeader spc (vlax-make-variant arr) 0))
           (if sty   (vl-catch-all-apply 'vla-put-StyleName   (list obj sty)))
           (if force (vl-catch-all-apply 'vla-put-ContentType (list obj 2))) ; 2 = MText
           (vla-put-TextString obj txt)
           (vl-catch-all-apply 'vla-put-Layer (list obj lay))
           obj
        )
      )
    )
    (if (vl-catch-all-error-p r) nil r)
  )

  (setq oldEcho  (getvar "CMDECHO"))
  (setq oldLayer (getvar "CLAYER"))
  (setvar "CMDECHO" 0)

  ;; Create and set layer 'corninates' if it doesn't exist
  (if (null (tblsearch "LAYER" targetLayer))
    (entmake
      (list
        '(0 . "LAYER")
        '(100 . "AcDbSymbolTableRecord")
        '(100 . "AcDbLayerTableRecord")
        (cons 2 targetLayer)
        '(70 . 0)
        '(62 . 3)
        '(6 . "Continuous")
      )
    )
  )
  (setvar "CLAYER" targetLayer)

  (setq curStyle (getvar "CMLEADERSTYLE"))

  (princ (strcat "\nActive Layer      : [" targetLayer "]"))
  (princ (strcat "\nMLeader Style     : [" curStyle "]"))
  (princ (strcat "\nUnit factor       : " (rtos unitFactor 2 6)
                 "  (drawing units -> meters)"))
  (princ "\n--- Pick point location (OSNAP is active; Enter or ESC to stop) ---")

  (while (setq pt1 (getpoint "\nSpecify point coordinate location: "))
    (setq pt2 (getpoint pt1 "\nSpecify leader landing location: "))

    (if pt2
      (progn
        (setq xM (* (car  pt1) unitFactor))
        (setq yM (* (cadr pt1) unitFactor))

        (setq strText (strcat "X: " (rtos xM 2 mPrec) " m"
                              "\\PY: " (rtos yM 2 mPrec) " m"))

        ;; 1. POINT entity at the picked location (true drawing units)
        (entmake
          (list
            '(0 . "POINT")
            (cons 8 targetLayer)
            (cons 10 pt1)
          )
        )

        ;; 2. MLEADER - ActiveX first, command line only as a fallback
        (setq ml (PTL:MakeMLeader pt1 pt2 strText targetLayer curStyle forceMText))
        (if (null ml)
          (progn
            (princ "\n[!] ActiveX MLeader failed - falling back to command line.")
            (vl-cmdf "_.MLEADER" pt1 pt2 strText)
          )
        )
      )
    )
  )

  (*error* nil)
  (princ "\nCompleted.")
  (princ)
)
(princ "\nPTLEAD loaded. Type PTLEAD to run.")
(princ)