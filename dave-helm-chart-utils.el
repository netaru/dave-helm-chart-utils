;;; dave-helm-chart-utils.el --- Run helm template from a chart with optional values override  -*- lexical-binding: t -*-

;; Author:    David Jonsson <david.jonsson306@gmail.com>
;; URL:       N/A
;; Version:   0.0.1
;; Package-Requires: ((emacs "26.1") (transient "0.4.3") (f "0.6.0"))

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
(defun dave-helm-open-values-file ()
  "Open the `dave-helm-values-override-file' if not nil."
  (interactive)
  (when dave-helm-values-override-file (find-file dave-helm-values-override-file)))

;;;###autoload
(defun dave-helm-open-chart ()
  "Open the `dave-helm-chart-directory' if not nil."
  (interactive)
  (when dave-helm-chart-directory (find-file dave-helm-chart-directory)))

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
    (let* ((project-dir (format "%s%s" temporary-file-directory (make-temp-name "emacs-helm-generate")))
           (values-file (concat project-dir "/values.yaml"))
           (values-file-old (concat project-dir "/values-old.yaml"))
           (buffer-name (generate-new-buffer-name "*helm-generated-templates*")))
      (copy-directory dave-helm-chart-directory project-dir)
      (when (and dave-helm-values-override-file (file-exists-p dave-helm-values-override-file))
        (rename-file values-file values-file-old)
        (f-write-text
         (shell-command-to-string
          (dave-helm-yq-build-command values-file-old dave-helm-values-override-file))
         'utf-8
         values-file))
      (with-output-to-temp-buffer buffer-name
        (call-process "helm" nil buffer-name nil "template" "generated" project-dir)
        (pop-to-buffer buffer-name)
        (yaml-mode))
      (delete-directory project-dir t))))

(require 'transient)

(transient-define-prefix dave-helm-chart ()
  "Generate helm templates."
  ["Options"
   ("v" (lambda () (format "Values: %s" (or dave-helm-values-override-file "")))  dave-helm-choose-override-file :transient t)
   ("c" (lambda () (format "Chart : %s" (or dave-helm-chart-directory ""))) dave-helm-choose-helm-directory :transient t)]
  ["Actions"
   ("e" "edit values" dave-helm-open-values-file)
   ("d" "edit chart" dave-helm-open-chart)
   ("g" "generate" dave-helm-generate-templates)])

(provide 'dave-helm-chart-utils)
;;; dave-helm-chart-utils.el ends here
