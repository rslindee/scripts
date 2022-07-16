#!/bin/sh
# recovers from "Git error: Encountered X file(s) that should have been pointers, but weren't" per https://stackoverflow.com/questions/46704572/git-error-encountered-7-files-that-should-have-been-pointers-but-werent/54221959

git rm --cached -r .
git reset --hard
git rm .gitattributes
git reset .
git checkout .
