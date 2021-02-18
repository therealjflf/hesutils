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
# For each test, the script creates additional files in the same directory as
# the test file:
#
# <testfile>.log    log messages from this test script
# <testfile>.out    test command stdout
# <testfile>.err    test command stderr
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
    nocolor=''

    if (( colors )) ; then
        nocolor='\e[0m'
        case $col in
            red)    color='\e[31;1m' ;;
            green)  color='\e[32;1m' ;;
            yellow) color='\e[33;1m' ;;
        esac
    fi

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

    if [[ "$RETVAL" ]] ; then
        if (( "$RETVAL" == "$testret" )) ; then
            echo "The return values match: $RETVAL"
        else
            echo "Mismatch in return values: expected $RETVAL, got $testret."
            failed=1
        fi
    fi

    if [[ "$OUTFILE" ]] ; then
        if cmp "$OUTFILE" "$ofile" ; then
            echo "The stdout outputs match."
        else
            echo "Mismatch in the output of stdout."
            failed=1
        fi
    fi

    if [[ "$ERRFILE" ]] ; then
        if cmp "$ERRFILE" "$efile" ; then
            echo "The stderr outputs match."
        else
            echo "Mismatch in the output of stderr."
            failed=1
        fi
    fi

    return $failed
}



# Run a single test
# ------------------------------------------------------------------------------

function run_test {

    # Clean up the previous test's environment
    unset CMDLINE OUTFILE ERRFILE RETVAL testret


    dirname="$(dirname "$1")"
    bname="$(basename "$1")"
    logfile="${1}.log"

    # Those will be the test's stdout and stderr files
    ofile="${bname}.out"
    efile="${bname}.err"


    (( ++testcount ))

    printf "%-16s: " "$1"


    # We're not writing to the logfile yet, as we don't know if the test file,
    # and the directory containing it, exist.
    if [[ ! -r "$1" ]] ; then
        colorprint yellow "Test file could not be read"
        (( ++didntrun ))
        return 1
    fi


    # We can now assume that we can create the log file, and redirect stdout and
    # stderr to it. Fear the syntax.
    exec 8>&1 9>&2 1>"$logfile" 2>&1


    #\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
    #
    #   EVERY OUTPUT TO STDOUT AND STDERR BELOW THIS LINE IS REDIRECTED TO
    #   THE LOG FILE.
    #
    #\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\


    pushd "$dirname" >/dev/null 2>&1


    #\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
    #
    #   EVERY PATH BELOW THIS LINE IS RELATIVE TO THE DIRECTORY CONTAINING
    #   THE TEST FILE, NOT THE PWD WHEN THE SCRIPT WAS EXECUTED.
    #
    #\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\


    # Load the test file and validate it
    # Skip to next test if something went wrong
    echo "*** Loading test file $bname"

    if ! source "$bname" || ! validate_env 2>&1 ; then
        popd >/dev/null 2>&1
        exec 1>&8 2>&9 8>&- 9>&-
        colorprint yellow "Didn't run"
        (( ++didntrun ))
        return 1
    fi


    # Run the command
    echo "*** Running the test:"
    echo "    ${CMDLINE[@]} 1>${ofile} 2>${efile}"
    eval "${CMDLINE[@]}" 1>"${ofile}" 2>"${efile}"
    testret=$?  # used in check_results

    echo "*** The test returned the value $testret"


    # And check the results
    check_results
    checkret=$?


    # Back to our original settings
    popd >/dev/null 2>&1
    exec 1>&8 2>&9 8>&- 9>&-


    #\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
    #
    #   EVERYTHING BELOW THIS LINE GOES BACK TO STDOUT AND STDERR, AND IS
    #   RELATIVE TO THE ORIGINAL PWD.
    #
    #\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\


    if ! (( $checkret )) ; then
        colorprint green "OK"
        (( ++successes ))
    else
        colorprint red "Failed"
        (( ++failures ))
    fi

    # Returns the return value of the test: 0 if OK, 1 if failed
}



# Main loop
# ------------------------------------------------------------------------------

(( $# )) || return


# Check if we can print in colors
[[ -t 1 ]] || colors=0



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

