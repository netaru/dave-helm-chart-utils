;;; dave-helm-chart-utils.el --- Run helm template from a chart with optional values override  -*- lexical-binding: t -*-

;; Author:    David Jonsson <david.jonsson306@gmail.com>
;; URL:       N/A
;; Version:   0.0.1
;; Package-Requires: ((emacs "26.1") (hydra "0.13.2"))

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Uses a simple structure of chart-directories and values-directories
;; to select a chart and values file.
;;
;; The chart will be copied to a temporary folder. Where the value file
;; will be merged with the override file using yq if `dave-helm-values-override-file' is set.
;;
;; Then a new buffer will appear with the generated templates.
;; If `dave-helm-chart-directory' is not set nothing will happen.

;;; Code:
(defcustom dave-helm-chart-directories nil
  "Directories that contains chart files."
  :group 'dave-helm
  :type '(repeat directory))

(defcustom dave-helm-values-directories nil
  "Directories that contains value files."
  :group 'dave-helm
  :type '(repeat directory))

(defcustom dave-helm-chart-directory nil
  "Current chart source directory."
  :group 'dave-helm
  :type 'directory)

(defcustom dave-helm-values-override-file nil
  "File to use to override values."
  :group 'dave-helm
  :type 'file)

(defun dave-helm-yq-build-command (initial &rest rs)
  "Build a `yq' command to combine values.yaml files. Starting with `initial' and extending/overriding it with `rs'"
  (format "yq -n '%s'" (string-join (seq-map (lambda (file) (format "load(\"%s\")" file)) (append (list initial) rs)) " * ")))

;;;###autoload
(defun dave-helm-choose-helm-directory ()
  (interactive)
  (let* ((targets (flatten-list
                   (seq-map
                    (lambda (folder) (split-string (shell-command-to-string (format "find %s -name 'Chart.yaml' -print0 | xargs -0 dirname" folder))))
                    dave-helm-chart-directories)))
         (chosen (completing-read "Which chart: " targets nil t)))
    (setopt dave-helm-chart-directory chosen)))

;;;###autoload
(defun dave-helm-choose-override-file ()
  (interactive)
  (let* ((targets (flatten-list
                   (seq-map
                    (lambda (folder) (split-string (shell-command-to-string (format "find %s -name 'values.yaml' -or -name 'values.yml'" folder))))
                    dave-helm-values-directories)))
         (chosen (completing-read "Which values file: " targets nil t)))
    (setopt dave-helm-values-override-file chosen)))

;;;###autoload
(defun dave-helm-generate-templates ()
  "Generate templates from the chosen chart using optional overrides for values.

Does nothing if `dave-helm-chart-directory' is not set.
"
  (interactive)
  (when (and dave-helm-chart-directory (file-exists-p dave-helm-chart-directory))
    (let* ((source dave-helm-chart-directory)
           (project (file-name-base source))
           (target (make-temp-file "emacs-helm-generate" t))
           (default-directory target)
           (project-dir (concat target "/" project))
           (values-file (concat project-dir "/values.yaml"))
           (values-file-override dave-helm-values-override-file)
           (values-file-new-location (concat project-dir "/values-old.yaml"))
           (buffer-name (generate-new-buffer-name "*helm-generated-templates*")))
      (copy-directory source project-dir)
      (when (and values-file-override (file-exists-p values-file-override))
        (rename-file values-file values-file-new-location)
        (f-write-text
         (shell-command-to-string
          (dave-helm-yq-build-command values-file-new-location values-file-override))
         'utf-8
         values-file))
      (with-output-to-temp-buffer buffer-name
        (call-process "helm" nil buffer-name nil "template" "generated" project-dir)
        (pop-to-buffer buffer-name)
        (yaml-mode))
      (delete-directory target t))))

(require 'hydra)

(defhydra dave-helm-hydra ()
  "
Run helm commands
_v_ : Choose a values file to use when generating templates
_c_ : Choose a chart folder to generate templates from
_g_ : Generate the templates
_q_ : Quit
"
  ("v" dave-helm-choose-override-file (or dave-helm-values-override-file ""))
  ("c" dave-helm-choose-helm-directory (or dave-helm-chart-directory ""))
  ("g" dave-helm-generate-templates "Generate templates" :exit t)
  ("q" nil "finished" :exit t))

(provide 'dave-helm-chart-utils)
;;; dave-helm-chart-utils.el ends here
