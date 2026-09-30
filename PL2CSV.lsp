;;; ==========================================================================
;;; Command: PL2CSV
;;; Description: Exports vertex coordinates of selected polylines
;;;              (LWPOLYLINE, 2D POLYLINE, 3D POLYLINE) to a CSV file.
;;; ==========================================================================

(vl-load-com)

(defun PL2CSV:Csv (s / p)
  (setq p 0)
  (while (setq p (vl-string-search "\"" s p))
    (setq s (vl-string-subst "\"\"" "\"" s p) p (+ p 2)))
  (strcat "\"" s "\"")
)

;;; Returns list of WCS vertex points for any polyline type
(defun PL2CSV:Vertices (ent / endP cnt k pts)
  (setq endP (fix (+ (vlax-curve-getEndParam ent) 1e-8))
        cnt  (if (vlax-curve-isClosed ent) endP (1+ endP))
        k    0)
  (repeat cnt
    (setq pts (cons (vlax-curve-getPointAtParam ent k) pts)
          k   (1+ k)))
  (reverse pts)
)

(defun c:PL2CSV ( / *error* ss i ent ed pts n v csvPath file oldDimzin sh
                    typ layer closed plNo)

  (defun *error* (msg)
    (if file (close file))
    (if oldDimzin (setvar "DIMZIN" oldDimzin))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*"))
      (princ (strcat "\nError: " msg)))
    (princ)
  )

  (princ "\nSelect polylines to export vertex coordinates: ")
  (cond
    ((not (setq ss (ssget '((0 . "LWPOLYLINE,POLYLINE")))))
     (princ "\nNo polylines selected."))

    ((not (setq csvPath
                (getfiled "Save Polyline Coordinates to CSV"
                          (strcat (getvar "DWGPREFIX")
                                  (vl-filename-base (getvar "DWGNAME")) "_Polylines")
                          "csv" 1)))
     (princ "\nCancelled."))

    ((not (setq file (open csvPath "w")))
     (princ "\nError: Unable to open file for writing. Close it in Excel and try again."))

    (t
     (setq oldDimzin (getvar "DIMZIN"))
     (setvar "DIMZIN" 0)

     (write-line "Index,Polyline No,Handle,Layer,Type,Closed,Vertex No,X (Easting),Y (Northing),Z (Elevation)" file)

     (setq n 0 i 0 plNo 0)
     (repeat (sslength ss)
       (setq ent    (ssname ss i)
             i      (1+ i)
             ed     (entget ent)
             layer  (cdr (assoc 8 ed))
             typ    (cond ((= (cdr (assoc 0 ed)) "LWPOLYLINE") "LWPolyline")
                          ((= 8 (logand 8 (cdr (assoc 70 ed)))) "3D Polyline")
                          (t "2D Polyline"))
             closed (if (vlax-curve-isClosed ent) "Yes" "No")
             pts    (PL2CSV:Vertices ent)
             plNo   (1+ plNo)
             v      0)
       (foreach pt pts
         (setq n (1+ n) v (1+ v))
         (write-line
           (strcat (itoa n) ","
                   (itoa plNo) ","
                   (cdr (assoc 5 ed)) ","
                   (PL2CSV:Csv layer) ","
                   typ ","
                   closed ","
                   (itoa v) ","
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

     (princ (strcat "\nExported " (itoa n) " vertices from "
                    (itoa plNo) " polyline(s) to: " csvPath))

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

(princ "\nType PL2CSV to export polyline vertex coordinates.")
(princ)