#!/usr/bin/env bash

# ==============================================================================
#
# Test infrastructure script
#
# ==============================================================================
#
# This file is part of Hesutils <https://gitlab.com/jflf/hesutils>
# Hesutils Copyright (c) 2019-2021 JFLF
#
# Hesutils is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Hesutils is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Hesutils. If not, see <https://www.gnu.org/licenses/>.
#
# ==============================================================================


# How it works
# ------------------------------------------------------------------------------
#
# Each test to run is described in an individual test file.
# Test files are valid Bash files. Comments start with #.
# Each test file contains the following variables:
#
# mandatory  CMDLINE=  array    command to run with its parameters
# optional   RETVAL=   integer  expected return value from the command
# optional   OUTFILE=  string   file containing expected stdout from command
# optional   ERRFILE=  string   file containing expected stderr from command
#
# Examples:
#   $ cat test1.test    
#   CMDLINE=( true )
#   RETVAL=0
#
#   $ cat test2.test
#   CMDLINE=( echo "abc def" )
#   OUTFILE=test2.out
#
#   $ cat test2.out
#   abc def
#
# The test are ran by calling this script with the list of test files:
#   $ ./run_tests *.test
#
# For each test, the script might create additional files in the same directory
# as the test file:
#
# <testfile>.log    always                     log of the steps of the test
# <testfile>.out    only if OUTFILE defined    command stdout, to compare
# <testfile>.err    only if ERRFILE defined    command stderr, to compare
#
# All file paths contained in the test file are relative to the location of the
# test file, not the current directory nor the path of the script.
#
# RETVAL, the contents of OUTFILE and the contents of ERRFILE will be compared,
# if those variable are defined, with the return code of the command and its
# stdout and stderr. The test is successful if no comparison failed.


set -e


# Global variables
# ------------------------------------------------------------------------------

colors=1

successes=0
failures=0
didntrun=0
testcount=0



# Helper functions
# ------------------------------------------------------------------------------

# Print a text in color, with an optional offset

# $1    color
# $2+   text to print

function colorprint {

    # exit if we don't have the right number of arguments
    (( $# >= 2 )) || return 1
    
    col="$1" ; shift

    color=''
    nocolor='\e[0m'

    # switch to color text
    case $col in
        red)    color='\e[31;1m' ;;
        green)  color='\e[32;1m' ;;
        yellow) color='\e[33;1m' ;;
    esac

    printf "${color}%s${nocolor}\n" "${*}"
}



# Validate the environment variables obtained from the test file
# ------------------------------------------------------------------------------

# Returns 0 for success, 1 for failure

function validate_env {

    failed=0

    echo "*** Checking the contents of the test file."

    if [[ ! "$CMDLINE" ]] ; then
        echo "ERROR: No CMDLINE defined in the test file."
        failed=1
    elif [[ ! "$(declare -p CMDLINE 2>/dev/null)" =~ ^declare\ -a ]] ; then
        echo "ERROR: CMDLINE is not an array."
        failed=1
    fi

    if [[ ! "$OUTFILE" && ! "$RETVAL" ]] ; then
        echo "ERROR: Neither OUTFILE nor RETVAL defined in the test file."
        failed=1
    fi

    if [[ "$RETVAL" && ! "$RETVAL" =~ ^[0-9]+$ ]] ; then
        echo "ERROR: RETVAL is not an integer: $RETVAL"
        failed=1
    fi

    if [[ "$OUTFILE" && ! -r "$OUTFILE" ]] ; then
        echo "ERROR: OUTFILE doesn't exist or is not readable: $OUTFILE"
        failed=1
    fi

    if [[ "$ERRFILE" && ! -r "$ERRFILE" ]] ; then
        echo "ERROR: ERRFILE doesn't exist or is not readable: $ERRFILE"
        failed=1
    fi

    return $failed
}



# Check the results of the tests
# ------------------------------------------------------------------------------

# Returns 0 for all tests successful, 1 for one or more failure(s)

function check_results {

    failed=0

    echo "*** Checking the results of the test."

    if [[ "$RETVAL" ]] && (( "$RETVAL" != "$ret" )) ; then
        echo "Mismatch in return values: expected $RETVAL, got $ret."
        failed=1
    fi

    if [[ "$OUTFILE" ]] && ! cmp "$OUTFILE" "$ofile" ; then
        echo "Mismatch in the output of stdout."
        failed=1
    fi

    if [[ "$ERRFILE" ]] && ! cmp "$ERRFILE" "$efile" ; then
        echo "Mismatch in the output of stderr."
        failed=1
    fi

    return $failed
}



# Run a single test
# ------------------------------------------------------------------------------

function run_test {

    # Clean up the previous test's environment
    unset CMDLINE OUTFILE ERRFILE RETVAL

    dirname="$(dirname "$1")"
    bname="$(basename "$1")"
    logfile="${bname}.log"

    (( ++testcount ))

    echo -n "$1 :  "

    if [[ ! -r "$1" ]] ; then
        colorprint yellow "File doesn't exist: $1"
        (( ++didntrun ))
        return 1
    fi

    pushd "$dirname" >/dev/null 2>&1

    # Load the test file and validate it
    # Skip to next test if something went wrong
    echo "*** Loading test file $bname" >>"$logfile"

    if ! source "$bname" >>"$logfile" 2>&1 || ! validate_env >>"$logfile" 2>&1 ; then
        colorprint yellow "Didn't run"
        (( ++didntrun ))
        popd >/dev/null 2>&1
        return 1
    fi

    # Output and error files for this test, if we need to compare them
    [[ "$OUTFILE" ]] && ofile="${bname}.out"
    [[ "$ERRFILE" ]] && efile="${bname}.err"

    # Run the command
    echo "*** Running the test:" >>"$logfile"
    echo "    ${CMDLINE[@]} 1>${ofile:-/dev/null} 2>${efile:-/dev/null}" >>"$logfile"
    "${CMDLINE[@]}" 1>"${ofile:-/dev/null}" 2>"${efile:-/dev/null}"
    ret=$?

    # And check the results
    if check_results >>"$logfile" 2>&1 ; then
        colorprint green "OK"
        (( ++successes ))
    else
        colorprint red "Failed"
        (( ++failures ))
    fi

    popd >/dev/null 2>&1
}



# Main loop
# ------------------------------------------------------------------------------

(( $# )) || return


# Check if we can print in colors
[[ -t 1 ]] || colors=0


# # Check that hesgen and hesadd are in the path
# if ! which hesadd hesgen >/dev/null 2>&1 ; then
#     echo "ERROR: Couldn't find hesadd and/or hesgen in the PATH." >&2
#     exit 1
# fi


# Loop over all test files in the current directory
for i in "${@}" ; do
    run_test "$i" || true
done


# Finally, display some statistics
echo
echo -n "Tests that ran successfully: " ; colorprint green $successes
echo -n "Tests that ran and failed:   " ; colorprint red $failures
echo -n "Tests that didn't run:       " ; colorprint yellow $didntrun
echo    "Total number of tests:       $testcount"

if (( failures )) || (( didntrun )) ; then
    exit 1
else
    exit 0
fi

