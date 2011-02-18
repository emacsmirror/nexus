;;; nexus.el --- REST Client for Nexus Maven Repository servers

;; Copyright (C) 2011  Juergen Hoetzel

;; Author: Juergen Hoetzel <juergen@archlinux.org>
;; Keywords: comm

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:

(require 'xml)
(require 'mm-url)

(require 'nexus-widget)

(defcustom nexus-rest-url
  "http://repository.sonatype.org/service/local/data_index"
  "URL of Nexus REST API. Customize if you use an private/custom Nexus server"
  :group 'nexus)

(defconst nexus-display-function 'nexus-widget-display)

(defun nexus--response-artifact-get-child (xml child-name)
  (car (xml-get-children xml child-name)))

(defun nexus--response-artifact-to-alist (xml)
  "transform xml artifact fragment to an alist"
  (let ((tag (car xml)))
    (if (eq tag 'artifact)
	(let* ((resource-uri-node (nexus--response-artifact-get-child xml 'resourceURI))
	       (resource-uri-value (nth 2 resource-uri-node))
	       (group-id-node (nexus--response-artifact-get-child xml 'groupId))
	       (group-id-value (nth 2 group-id-node))
	       (artifact-id-node (nexus--response-artifact-get-child xml 'artifactId))
	       (artifact-id-value (nth 2 artifact-id-node))
	       (version-node (nexus--response-artifact-get-child xml 'version))
	       (version-value (nth 2 version-node))
	       (packaging-node (nexus--response-artifact-get-child xml 'packaging))
	       (packaging-value (nth 2 packaging-node)))
	  `((:resourceURI ,resource-uri-value)
	    (:groupId ,group-id-value)
	    (:artifactId ,artifact-id-value)
	    (:version ,version-value)
	    (:packaging ,packaging-value)))
      (warn "Invalid XML fragment: %s" tag))))

;; FIXME: This should be filtered by RST webservice?
(defun nexus-artifact-jar-p (artifact)
  (message "%s" artifact)
  (string= "jar" (cadr (assoc :packaging artifact))))

(defun nexus--response-artifacts (xml)
  "Return search-results->data->artifact childrens of search response"
  (xml-get-children 
   (first (xml-get-children 
	   ;; only one node: search-results
	   (first xml)
	   'data))
   'artifact))

(defun nexus-search-internal (qstring)
  (let ((url (format "%s?%s" nexus-rest-url qstring)))
    (condition-case err
	(progn 
	  (with-temp-buffer
	    (mm-url-insert url)
	    (let ((results (remove-if-not 'nexus-artifact-jar-p
					  (mapcar 'nexus--response-artifact-to-alist
						  (nexus--response-artifacts (xml-parse-region (point-min) (point-max)))))))
	      (if results
		  (nexus-widget-display results)
		(message "No search results")))))
      (error (if (or debug-on-quit debug-on-error)
		 (signal (car err) (cdr err))
	       (message "nnrss: Failed to fetch %s" url))))))

(defun nexus-search-keyword (keyword)
  (interactive "sNexus keyword search: ")
  (nexus-search-internal (concat "q=" (mm-url-form-encode-xwfu keyword))))

(defun nexus-search-coordinates (group-id artifact-id version packaging classifier)
  "Search Nexus repository by coordinates (groupId, artifactId, version, packaging, classifier as descriped in
 
    http://maven.apache.org/pom.html#Maven_Coordinates"
  (interactive "sgroupId: \nsartifactId: \nsversion: \nspackaging: \nsclassifier: ")
  (let* ((pairs (list (cons "g" group-id) (cons "a" artifact-id) (cons "v" version) (cons "p" packaging) (cons "%c" classifier)))
	 (qstring (mm-url-encode-www-form-urlencoded (remove-if-not (lambda (p) (string-match "[[:alnum:]]" (cdr p))) pairs))))
    (nexus-search-internal qstring)))

(defun nexus-search-classname (classname)
  (interactive "sNexus class name search: ")
  (nexus-search-internal (concat "cn=" (mm-url-form-encode-xwfu classname))))

(provide 'nexus) 
;;; nexus.el ends here
