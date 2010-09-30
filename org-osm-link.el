;;; org-osm-link.el --- Org-links to OSM maps

;; Copyright (c) 2010 Sebastian Rose, sebastian_rose gmx de
;; Authors:    Sebastian Rose, sebastian_rose gmx de

;; Released under the GNU General Public License version 3
;; see: http://www.gnu.org/licenses/gpl-3.0.html

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Add a special Org link type, that, when clicked, opens an
;; SVG image of a certain track.

;; Example link:
;;   [[track:((12.0399212 14.919293)(32.12394 15.342345))FILE.svg][Track]]

;; An link's path consists of a list of coordinates and the
;; filename.  As usual, the description part (\"Track\" in
;; this case) is optional.
;; See the documentation for `osm-track-regexp' for a
;; description of the coordinates.

;; Installation
;; ------------

;; Make sure `osm-maps.el' and `org-osm-link.el' are in your
;; `load-path' and add this to your emacs setup:
;;     (require 'org-osm-link)


;;; Code:

(require 'org)
(require 'osm-maps)


;;; Custom Variables

(defcustom osm-org-export-html-format "<a href=\"%s\" target=\"_blank\">%s</a>"
  "Format for Org mode's XHTML export of OSM tracks.
The format should contain two place holders.  The first one
for the image's relative filename, the second one for the
link description."
  :group 'osm-maps
  :type  'string)


(defcustom osm-org-export-LaTeX-format
  "\\href{file://%F}{%d}"
  "Format used to export a track: link to LaTeX.
Possible replacements:
 \"%F\"  -  absolute path to the image
 \"%f\"  -  relative path to the image
 \"%d\"  -  link description or the image's relative path"
  :group 'osm-maps
  :type  'string)


(defcustom osm-org-image-viewer-function 'osm-org-show-track
  "Function to call if a track image should be shown.
The function is called with one argument: the absolute path
to the image file.

Here is an example for use with Gnome:
  (setq osm-org-image-viewer-function
        (lambda (file)
          (call-process \"gnome-open\" nil 0 nil file)))"
  :group 'osm-maps
  :type  'function)


;;; Functions

(defun osm-org-compose-link ()
  "Store a link for a certain track.
The link is not validated currently but the .svg extension
is added as needed."
  (interactive)
  (let* ((crds (read-from-minibuffer "Coords: "))
         (file (read-from-minibuffer "Filename: "))
         (desc (read-from-minibuffer "Desription: " file)))
    (unless (string-match "\\.svg$" file)
      (setq file (concat file ".svg")))
    (insert "[[track:" crds file "][" desc "]]")))


(defun osm-org-show-track (target)
  (let ((file (file-name-nondirectory target)))
    (if (get-buffer file)
        (switch-to-buffer file)
      (find-file target))))


(defun osm-org-link-follow (path)
  "Follow the Org mode link when clicked."
  (let* ((coords (osm-check-track path))
         (file (match-string 2 path))
         (target file))
    (unless (file-exists-p target)
      ;; if no file exists, the name will be made
      ;; in osm-draw-track for us:
      (setq target (osm-draw-track coords file)))
    (funcall osm-org-image-viewer-function
             (file-truename target))))


(defun osm-org-link-export (path description format)
  "Export a track from Org files."
  (let* ((coords (osm-check-track path))
         (file (match-string 2 path))
         (target (file-relative-name file))
         (desc (or description target)))
    (unless (file-exists-p target)
      ;; if no file exists, the name will be made
      ;; in osm-draw-track for us:
      (setq target (file-relative-name (osm-draw-track coords file)))
      (setq desc (or description target)))
    (cond
     ((eq format 'html)
      (format osm-org-export-html-format
              (file-relative-name target) desc))
     ((eq format 'latex)
      (org-replace-escapes
       osm-org-export-LaTeX-format
       (list (cons "%f" target)
             (cons "%F" (expand-file-name target))
             (cons "%d" desc))))
     (t
      (file-relative-name target)))))


(defun osm-publish-map-for-html (plist file pubdir)
  "Publish existing maps for use with HTML files.
For this to work, you'll need to set up a special publishing
project in you `org-publish-project-alist'.  Here is an
example:

  (\"org-osm-maps\"
   :base-directory \"~/org/training/\"
   :publishing-directory \"~/public_html/org/training/\"
   :recursive t
   :base-extension \"svg\"
   :osm-cache-directory \"~/org/img/OSM/\"
   :publishing-function osm-publish-map-for-html)

:osm-cache-directory denotes the path to link the background
tiles to.  Not checked for existence."
  (let* ((target (concat
                  (file-name-as-directory pubdir)
                  (file-name-nondirectory file)))
         (old-path (concat
                    "file://"
                    (file-name-as-directory
                     (expand-file-name osm-default-cache-directory))))
         (new-path (concat
                    ""
                    (file-name-as-directory
                     (file-relative-name
                      (plist-get plist :osm-cache-directory)
                      (file-name-directory file)))))
         (ama auto-mode-alist))

    (unwind-protect
        (progn
          (setq auto-mode-alist nil)
          (with-temp-buffer
            (insert-file file)
            (beginning-of-buffer)
            (replace-string old-path new-path)
            (write-file target)))
      ;; clean up forms:
      (setq auto-mode-alist ama))
))


;;; Finally install the link type

(org-add-link-type
 "track"
 'osm-org-link-follow
 'osm-org-link-export)


(provide 'org-osm-link)

;;; org-osm-link.el ends here
