;;; ==========================================================================
;;; Command: MLE2CSV
;;; Description: Exports Multileader (MLEADER) arrow-tip coordinates and their
;;;              text/block content to a CSV file.
;;; ==========================================================================

(vl-load-com)

;;; --- Strip MText formatting codes (\P, \f..;, \H..;, \C..;, \S..^..;, {}) ---
(defun MLE:StripMText (s / out i n c nx p)
  (setq out "" i 1 n (strlen s))
  (while (<= i n)
    (setq c (substr s i 1))
    (cond
      ((= c "\\")
       (setq nx (substr s (1+ i) 1))
       (cond
         ;; paragraph / column break / non-breaking space -> space
         ((member nx '("P" "~" "N" "X")) (setq out (strcat out " ") i (+ i 2)))
         ;; escaped literal characters
         ((member nx '("\\" "{" "}")) (setq out (strcat out nx) i (+ i 2)))
         ;; stacked fraction \Sa^b;  ->  a/b
         ((= nx "S")
          (setq p (vl-string-search ";" s i))
          (if p
            (setq out (strcat out (vl-string-translate "^#" "//" (substr s (+ i 2) (- p i 1))))
                  i   (+ p 2))
            (setq i (1+ n))))
         ;; codes terminated by ';'  (\f \F \H \C \c \T \Q \W \A \p)
         ((member (strcase nx) '("F" "H" "C" "T" "Q" "W" "A" "P"))
          (setq p (vl-string-search ";" s i))
          (setq i (if p (+ p 2) (1+ n))))
         ;; toggles \L \l \O \o \K \k etc.
         (t (setq i (+ i 2)))))
      ((member c '("{" "}")) (setq i (1+ i)))
      ((member c '("\t" "\r" "\n")) (setq out (strcat out " ") i (1+ i)))
      (t (setq out (strcat out c) i (1+ i)))))
  (while (vl-string-search "  " out) (setq out (vl-string-subst " " "  " out)))
  (vl-string-trim " " out)
)

;;; --- Quote a CSV field (commas kept, embedded quotes doubled) ---
(defun MLE:Csv (s / p)
  (setq p 0)
  (while (setq p (vl-string-search "\"" s p))
    (setq s (vl-string-subst "\"\"" "\"" s p) p (+ p 2)))
  (strcat "\"" s "\"")
)

;;; --- Content of the MLeader: MText, block name, or none ---
(defun MLE:Content (obj / ct r)
  (setq ct (vl-catch-all-apply 'vla-get-ContentType (list obj)))
  (cond
    ((vl-catch-all-error-p ct) "")
    ((= ct 2)                                        ; acMTextContent
     (setq r (vl-catch-all-apply 'vla-get-TextString (list obj)))
     (if (vl-catch-all-error-p r) "" (MLE:StripMText r)))
    ((= ct 1)                                        ; acBlockContent
     (setq r (vl-catch-all-apply 'vla-get-ContentBlockName (list obj)))
     (if (vl-catch-all-error-p r) "[BLOCK]" (strcat "[BLOCK] " r)))
    (t "")
  )
)

;;; --- Arrow tips = first vertex (group 10) of every LEADER_LINE{ section ---
(defun MLE:ArrowTips (ent / inLine pts)
  (foreach g (entget ent)
    (cond
      ((and (= (car g) 304) (= (cdr g) "LEADER_LINE{")) (setq inLine T))
      ((and inLine (= (car g) 10)) (setq pts (cons (cdr g) pts) inLine nil))
      ((= (car g) 305) (setq inLine nil))
    )
  )
  (reverse pts)
)

;;; --- Main command ---
(defun c:MLE2CSV ( / *error* ss i j n ent obj txt csvPath file oldDimzin sh)

  (defun *error* (msg)
    (if file (close file))
    (if oldDimzin (setvar "DIMZIN" oldDimzin))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*"))
      (princ (strcat "\nError: " msg)))
    (princ)
  )

  (princ "\nSelect Multileaders to export coordinates: ")
  (cond
    ((not (setq ss (ssget '((0 . "MULTILEADER")))))
     (princ "\nNo Multileaders selected."))

    ((not (setq csvPath
                (getfiled "Save Multileader Coordinates to CSV"
                          (strcat (getvar "DWGPREFIX")
                                  (vl-filename-base (getvar "DWGNAME")) "_MLeaders")
                          "csv" 1)))
     (princ "\nCancelled."))

    ((not (setq file (open csvPath "w")))
     (princ "\nError: Unable to open file for writing. Close it in Excel and try again."))

    (t
     (setq oldDimzin (getvar "DIMZIN"))
     (setvar "DIMZIN" 0)                               ; keep trailing zeros in rtos

     (write-line "Index,Handle,Text Content,Leader No,X (Easting),Y (Northing),Z (Elevation)" file)

     (setq n 0 i 0)
     (repeat (sslength ss)
       (setq ent (ssname ss i)
             i   (1+ i)
             obj (vlax-ename->vla-object ent)
             txt (MLE:Content obj)
             j   0)
       (foreach pt (MLE:ArrowTips ent)
         (setq n (1+ n) j (1+ j))
         (write-line
           (strcat (itoa n) ","
                   (vla-get-Handle obj) ","
                   (MLE:Csv txt) ","
                   (itoa j) ","
                   (rtos (car pt) 2 4) ","
                   (rtos (cadr pt) 2 4) ","
                   (rtos (caddr pt) 2 4))
           file)
       )
     )

     (close file)
     (setq file nil)
     (setvar "DIMZIN" oldDimzin)
     (setq oldDimzin nil)

     (princ (strcat "\nExported " (itoa n) " leader point(s) from "
                    (itoa (sslength ss)) " Multileader(s) to: " csvPath))

     (initget "Yes No")
     (if (/= (getkword "\nOpen CSV file now? [Yes/No] <Yes>: ") "No")
       (progn
         (setq sh (vlax-create-object "Shell.Application"))
         (vl-catch-all-apply 'vlax-invoke (list sh 'ShellExecute csvPath))
         (vlax-release-object sh)
       )
     )
    )
  )
  (princ)
)

(princ "\nType MLE2CSV to run the Multileader export command.")
(princ)