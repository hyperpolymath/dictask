; SPDX-License-Identifier: MPL-2.0
;; guix.scm — GNU Guix package definition for dictask
;; Usage: guix shell -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses))

(package
  (name "dictask")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (synopsis "dictask")
  (description "dictask — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/dictask")
  (license mpl2.0))
