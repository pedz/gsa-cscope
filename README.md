gsa-cscope
==========

Add-on to cscope to help with GSA and OSF build trees.

This adds to the cscope-dir-patterns to match a users sandbox and the
backing trees held in GSA.  It also creates convenience functions to
start cscope within a particular backing tree.  Last, it adds in the
osf-dce enhancement to find files held in the backing tree when given
a file in a sandbox (i.e. it understands the OSF build system).
