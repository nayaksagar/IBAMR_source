#!/bin/sh
################################################################################
# Title         : generateDocumentationAndDeploy.sh
# Date created  : 2016/02/22
# Notes         :
__AUTHOR__="Jeroen de Bruijn"
# Preconditions:
# - Packages doxygen doxygen-doc doxygen-latex doxygen-gui graphviz
#   must be installed.
# - Doxygen configuration file must have the destination directory empty and
#   source code directory with a $(TRAVIS_BUILD_DIR) prefix.
# - An gh-pages branch should already exist. See below for mor info on hoe to
#   create a gh-pages branch.
#
# Required global variables:
# - TRAVIS_BUILD_NUMBER : The number of the current build.
# - TRAVIS_COMMIT       : The commit that the current build is testing.
# - DOXYFILE            : The Doxygen configuration file.
# - GH_REPO_NAME        : The name of the repository.
# - GH_REPO_REF         : The GitHub reference to the repository.
# - GH_REPO_TOKEN       : Secure token to the github repository.
#
# For information on how to encrypt variables for Travis CI please go to
# https://docs.travis-ci.com/user/environment-variables/#Encrypted-Variables
# or https://gist.github.com/vidavidorra/7ed6166a46c537d3cbd2
# For information on how to create a clean gh-pages branch from the master
# branch, please go to https://gist.github.com/vidavidorra/846a2fc7dd51f4fe56a0
#
# This script will generate Doxygen documentation and push the documentation to
# the gh-pages branch of a repository specified by GH_REPO_REF.
# Before this script is used there should already be a gh-pages branch in the
# repository.
# 
################################################################################

################################################################################
##### Setup this script and get the current gh-pages branch.               #####
echo 'Setting up the script...'
# Exit with nonzero exit code if anything fails
set -e

# Create a clean working directory for this script.
  mkdir -p code_docs
  cd code_docs
  export ROOT_DIR=$PWD

# Get the docs repo
git clone https://${DOCS_REPO_REF}
export DOCS_REPO=$ROOT_DIR/IBAMR-Docs
#####cd $ROOT_DIR/$GH_REPO_NAME

##### Configure git.
# Set the push default to simple i.e. push only the current branch.
git config --global push.default simple
# Pretend to be an user called Travis CI.
git config user.name "Travis CI"
git config user.email "travis@travis-ci.org"

# Remove everything currently in the gh-pages branch.
# GitHub is smart enough to know which files have changed and which files have
# stayed the same and will only update the changed files. So the gh-pages branch
# can be safely cleaned, and it is sure that everything pushed later is the new
# documentation.
#####rm -rf *

# Create the directory where Doxygen will output files.
mkdir -p html/ibamr/html

# Need to create a .nojekyll file to allow filenames starting with an underscore
# to be seen on the gh-pages site. Therefore creating an empty .nojekyll file.
# Presumably this is only needed when the SHORT_NAMES option in Doxygen is set
# to NO, which it is by default. So creating the file just in case.
echo "" > .nojekyll

# Grab the libstdc++ tagfile and move into the doc directory
wget https://gcc.gnu.org/onlinedocs/libstdc++/latest-doxygen/libstdc++.tag
mv libstdc++.tag $TRAVIS_BUILD_DIR/doc

################################################################################
##### Generate the Doxygen code documentation and log the output.          #####
echo 'Generating Doxygen code documentation...'
# Redirect both stderr and stdout to the log file AND the console.
cd $TRAVIS_BUILD_DIR/doc
echo "making Doxygen in $PWD"
echo "here is some stuff to check:"
echo $PWD
echo $DOXYFILE
echo $ROOT_DIR
echo $DOCS_REPO
doxygen $DOXYFILE 2>&1 | tee doxygen.log
echo 'Contents of directory'
ls -al

################################################################################
##### Upload the documentation to the gh-pages branch of the repository.   #####
# Only upload if Doxygen successfully created the documentation.
# Check this by verifying that the html directory and the file html/index.html
# both exist. This is a good indication that Doxygen did it's work.
if [ -d "html/ibamr/html" ] && [ -f "html/ibamr/html/index.html" ]; then
    
    export HTMLDIR=$PWD/html/ibamr
    cd $DOCS_REPO
    rm -rf ibamr
    mv $HTMLDIR .
    echo 'Uploading documentation to the docs repo...'
    # Add everything in this directory (the Doxygen code documentation) to the
    # docs repo.
    # GitHub is smart enough to know which files have changed and which files have
    # stayed the same and will only update the changed files.
    echo 'Adding files to git...'
    git add --all

    # Commit the added files with a title and description containing the Travis CI
    # build number and the GitHub commit reference that issued this build.
    echo 'Committing files to git...'
    git commit -m "Deploy code docs to GitHub Pages Travis build: ${TRAVIS_BUILD_NUMBER}" -m "Commit: ${TRAVIS_COMMIT}"

    # Force push to the remote gh-pages branch.
    # The ouput is redirected to /dev/null to hide any sensitive credential data
    # that might otherwise be exposed.
    echo 'pushing files to docs repo'
    git push --force "https://${GH_REPO_TOKEN}@${DOCS_REPO_REF}" > /dev/null 2>&1
else
    echo '' >&2
    echo 'Warning: No documentation (html) files have been found!' >&2
    echo 'Warning: Not going to push the documentation to GitHub!' >&2
    exit 1
fi

