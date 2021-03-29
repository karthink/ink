;;; ink.el --- Insert images in a LaTeX document using inkscape.

;;; Commentary:
;; You can insert a new figure at point using ink-make-figure or
;; edit an existing figure with ink-edit-figure.
;; This assumes you have inkscape installed.

;;; Code:
(defvar ink-fig-dir "figures"
  "Default image directory.")

(defvar ink-flags (list "--export-area-drawing"
                        "--export-dpi 300"
                        "--export-type=pdf"
                        "--export-latex"
                        "--export-overwrite")
  "Default list of flags for inkscape.")

(defvar ink-process-cmnd 'ink-process-cmnd-default
  "Function to make command from the svg file and the flags.")

(defvar ink-latex "\n\\begin{figure}
    \\centering
    \\def\\svgwidth{\\columnwidth}
    \\import{%s}{%s.pdf_tex}
    \\label{fig:%s}
    \\caption{}
\\end{figure}\n"
  "Default latex insert.")

(defvar ink-temp-dir "temp"
  "Default name for the temporary directory.")

(defvar ink-default-file
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<svg
   xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
   xmlns:cc=\"http://creativecommons.org/ns#\"
   xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
   xmlns:svg=\"http://www.w3.org/2000/svg\"
   xmlns=\"http://www.w3.org/2000/svg\"
   xmlns:sodipodi=\"http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd\"
   xmlns:inkscape=\"http://www.inkscape.org/namespaces/inkscape\"
   width=\"240mm\"
   height=\"120mm\"
   viewBox=\"0 0 240 120\"
   version=\"1.1\"
   id=\"svg8\"
   inkscape:version=\"1.0.2 (e86c870879, 2021-01-15)\"
   sodipodi:docname=\"default.svg\">
  <defs
     id=\"defs2\" />
  <sodipodi:namedview
     id=\"base\"
     pagecolor=\"#ffffff\"
     bordercolor=\"#666666\"
     borderopacity=\"1.0\"
     inkscape:pageopacity=\"0.0\"
     inkscape:pageshadow=\"2\"
     inkscape:zoom=\"0.85\"
     inkscape:cx=\"440\"
     inkscape:cy=\"240\"
     inkscape:document-units=\"mm\"
     inkscape:current-layer=\"layer1\"
     inkscape:document-rotation=\"0\"
     showgrid=\"false\"
     inkscape:window-width=\"1920\"
     inkscape:window-height=\"1068\"
     inkscape:window-x=\"1920\"
     inkscape:window-y=\"1068\"
     inkscape:window-maximized=\"0\" />
  <metadata
     id=\"metadata5\">
    <rdf:RDF>
      <cc:Work
         rdf:about=\"\">
        <dc:format>image/svg+xml</dc:format>
        <dc:type
           rdf:resource=\"http://purl.org/dc/dcmitype/StillImage\" />
        <dc:title></dc:title>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:label=\"Layer 1\"
     inkscape:groupmode=\"layer\"
     id=\"layer1\" />
</svg>"
     "Default file template.")

(defun ink-post-process (tdir)
  "Move files to image directory and remove TDIR."
  (let* ((temp (expand-file-name ink-fig-dir default-directory))
         (idir (file-name-as-directory temp)))
    (copy-directory tdir idir nil t t)
    (delete-directory tdir t nil)
    (message "done")))

(defun ink-insert-tex (file)
  "Insert tex string associated with FILE."
  (let* ((fdir (expand-file-name ink-fig-dir default-directory))
         (dname (file-name-directory file))
         (fname (file-name-nondirectory file))
         (name (file-name-sans-extension fname))
         (caption (downcase name))
         (ltex (format ink-latex fdir name caption)))
    (message dname)
    (insert ltex)))

(defun ink-process-cmnd-default (file flags)
  "Make command to convert a FILE to tex using the FLAGS."
  (concat "inkscape" " " file " " flags))

(defun ink-process ()
  "Use inkspace to create an image and tex."
  (let* ((tdir (expand-file-name ink-temp-dir default-directory))
         (files-all (directory-files tdir t "\\.svg$"))
         (flags (mapconcat 'identity ink-flags " ")))
    (dolist (file files-all (ink-post-process tdir))
      (shell-command (funcall ink-process-cmnd file flags))
      (ink-insert-tex file))))

(defun ink-sentinel (process event)
  "Wait for inkscape PROCESS to close but has no use for EVENT."
  (when (memq (process-status process) '(exit signal))
    (ink-process)))

(defun ink-edit-svg (fsvg)
  "Edit and existing svg file named FSVG."
  (let* ((log-buffer (get-buffer-create "*inky-log*"))
         (tdir (expand-file-name ink-temp-dir default-directory))
         (fname (file-name-nondirectory fsvg))
         (file (concat (file-name-as-directory tdir) fname)))
    (make-directory tdir t)
    (rename-file fsvg file)
    (make-process :name "inksape"
                  :buffer log-buffer
                  :command (list "inkscape" file)
                  :stderr log-buffer
                  :sentinel 'ink-sentinel)))

(defun ink-make-figure (fig)
  "Make a new figure named FIG and insert it at point."
  (interactive "sFigure name: ")
  (let* ((log-buffer (get-buffer-create "*inky-log*"))
         (tdir (expand-file-name ink-temp-dir default-directory))
         (file (concat (file-name-as-directory tdir) fig ".svg")))
    (make-directory tdir t)
    (write-region ink-default-file nil file)
    (make-process :name "inksape"
                  :buffer log-buffer
                  :command (list "inkscape" file)
                  :stderr log-buffer
                  :sentinel 'ink-sentinel)))

(defun ink-edit-figure ()
  "Edit existing figure or related tex file."
  (interactive)
  (let* ((fdir (expand-file-name ink-fig-dir default-directory))
         (pick (read-file-name "Edit file: " fdir))
         (file (expand-file-name pick default-directory))
         (type (file-name-extension file nil)))
    (if (string= type "svg")
        (ink-edit-svg file)
      (find-file file))))

(provide 'ink)
;;; ink.el ends here
