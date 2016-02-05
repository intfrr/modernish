#! /module/for/moderni/sh
#
# opts/long
#
# Add support for GNU-style --option and --option=argument long options to
# the 'getopts' shell builtin, using a new --long=<longoptstring> option.
#
# Usage: getopts [ --long=<longoptstring> ] <optstring> <varname> [ <arg> ... ]
# The <longoptstring> is analogous to the getopt builtin's <optstring>, but
# is space and/or comma separated. Each long option specification is a glob
# pattern, to facilitate spelling variants, etc. All other arguments are
# those of the original 'getopts' built-in function. (TODO: document further.)
# In this version of long options, the = for adding an argument is mandatory.
#
# Example invocation:
#
# while getopts --long='file:,list,number:,version,help,licen[sc]e' 'f:ln:vhL' opt; do
#    case $opt in
#    ( f | -file )       opt_file=$OPTARG ;;
#    ( l | -list )       opt_list=y ;;
#    ( n | -number )     opt_filenumber=$OPTARG ;;  
#    ( v | -version )    showversion; exit ;;
#    ( h | -help )       showversion; showhelp; exit ;;
#    ( L | -licen[sc]e ) showversion; showlicense; exit ;;
#    ( '?' )             exit -u 2 ;;
#    ( * )               exit 3 'internal error' ;;
#    esac
# done
# shift $((OPTIND-1))
#
# USAGE NOTE: When there is no option to an argument, POSIX specifies that
# OPTARG must be unset, but some shells make OPTARG empty instead. This bug
# is not bad enough to block on, but don't use 'isset OPTARG' to test if
# there is an argument! Instead, use 'empty "${OPTARG-}"'.
#
# The specification for the built-in getopts function is at:
# http://pubs.opengroup.org/onlinepubs/9699919799/utilities/getopts.html
#
# How it works:
#
# This function uses the "getopts" built-in to parse both short and long
# options using technique I've invented, which works as follows. A long
# option "option" with an argument "argument", taking the form
# "--option=argument", is redefined as a short option "--" with an argument
# "option=argument". The getopts built-in readily accepts this, if we just
# add "-:" at the end of the getopts short option string to accept that
# special short option '--' plus argument. Then, to parse long options
# correctly, all this function needs to do is split $OPTARG, putting the bit
# to the left of the = in the specified option variable.
#
# Surprisingly, this techique works in every POSIX-compliant shell I've
# tested and even in the original Bourne shell (as provided by Heirloom).
#
# There is a funny but harmless side effect. In getopts, short options and
# their arguments can be separated by spaces as well as combined with other
# short options that don't have arguments. So, since we're defining a long
# option in terms of a short option "--", you would expect that you can say
# "-- option=argument", but that is blocked because "--" by itself has the
# special meaning of "stop parsing options". However, given argumentless
# short options x, y and z, you *can* say strange things like
# "-xyz-option=argument" or even "-xyz- option=argument". Hopefully, no one
# will notice. ;)


# --- Initialization: OPTIND bug test. ---

# Some shells don't support calling "getopts" from a shell function; the
# standard specifies that OPTIND remains a global variable, but when the
# getopts builtin is called from a shell function, (d)ash stops updating
# it after parsing the first option, and zsh doesn't update it at all
# because it makes OPTIND a mandatory function-local variable.
# bash, ksh93, pdksh, mksh and yash all work fine.
# (NEWS: zsh fixes this in POSIX mode as of version 5.0.8.)
#
# TODO: for shells with function-local internal getopts state (i.e. all
# Almquist derivatives, which are far too common to ignore), implement a
# complete POSIX-compatible getopts replacement that parses both short and
# long options using pure shell code.

push OPTIND OPTARG
OPTIND=1
unset -v _Msh_gO_bug

_Msh_gO_callgetopts() {
	getopts 'D:ln:vhL' _Msh_gO_opt "$@"
}

_Msh_gO_testfn() {
	eq "$OPTIND" 1 || return

	_Msh_gO_callgetopts "$@"
	same "$_Msh_gO_opt" D && same "${OPTARG-}" test || return

	_Msh_gO_callgetopts "$@"
	same "$_Msh_gO_opt" h && empty "${OPTARG-}" || return

	_Msh_gO_callgetopts "$@"
	same "$_Msh_gO_opt" n && same "${OPTARG-}" 1 || return

	_Msh_gO_callgetopts "$@"
	eq "$OPTIND" 5 || return
}

# Don't change the test arguments in any way without changing
# the expected results in _Msh_gO_testfn() accordingly!
_Msh_gO_testfn -D 'test' -hn 1 'test' 'arguments'

if not so; then
	print	"opts/long: On this shell, 'getopts' has a function-local internal" \
		"           state, so this module can't use a function to extend its" \
		"           functionality.${ZSH_VERSION+ (zsh 5.0.8 fixes this)}"
	_Msh_gO_bug=y
fi

unset -v _Msh_gO_opt
unset -f _Msh_gO_testfn _Msh_gO_callgetopts
pop OPTIND OPTARG

if isset _Msh_gO_bug; then
	unset -v _Msh_gO_bug
	return 2
fi


# --- THE ACTUAL THING ---

alias getopts='_Msh_doGetOpts "$#" "$@"'
_Msh_doGetOpts() {
	if not isset OPTIND; then
		die "getopts: OPTIND not set"
	# yash sets $OPTIND to two values like '1:2' so we can't validate it.
	#elif not isint $OPTIND || lt "$OPTIND" 0; then
	#	die "getopts: OPTIND corrupted (value is $OPTIND)"
	fi

	# On zsh < 5.0.8, '$#-' in arith triggers BUG011.
	if gt "$#-($1+1)" 3 || {  gt "$# -($1+1)" 2 && eval "not startswith \"\$$(( $1 + 2 ))\" '--long='"; }
	then
		# The options to parse were given on the command line,
		# so discard caller's positional parameters.
		shift "$(( $1 + 1 ))"
	elif ge "$1" 1; then
		# The alias passes the caller's positional parameters to the
		# function first, before any arguments to 'getopts'. Reorder the
		# parameters so the arguments to 'getopts' come first, not last.
		storeparams -f2 -t"$(( $1 + 1 ))" _Msh_gO_callersparams
		shift "$(( $1 + 1 ))"
		eval "set -- \"\$@\" ${_Msh_gO_callersparams}"
		unset -v _Msh_gO_callersparams
	else
		# The alias did not pass any positional parameters.
		shift
	fi

	# Extract --long= option (if given).
	if startswith "$1" '--long='; then
		_Msh_gO_LongOpts="${1#--long=}"
		_Msh_gO_ShortOpts="$2"
		_Msh_gO_VarName="$3"
		shift 3
	else
		_Msh_gO_LongOpts=''
		_Msh_gO_ShortOpts="$1"
		_Msh_gO_VarName="$2"
		shift 2
	fi

	# Run the builtin (adding '-:' to the short opt string to parse the
	# special short option '--' plus arg) and check the results.
	command getopts "${_Msh_gO_ShortOpts}-:" "${_Msh_gO_VarName}" "$@"

	case "$?" in
	( 0 )	# don't do anything extra if it's not a long option
		if not eval "same \"\$${_Msh_gO_VarName}\" '-'"; then
			return 0
		fi ;;
	( 1 )	return 1 ;;
	( * )	die "getopts: error from the getopts built-in command" || return ;;
	esac

	# Split long option from its argument and add leading dash.
	_Msh_gO_Opt="-${OPTARG%%=*}"
	if same "$_Msh_gO_Opt" "-$OPTARG"; then
		OPTARG=''
	else
		OPTARG="${OPTARG#*=}"
	fi

	# Check it against the provided list of long options.
	unset -v _Msh_gO_NoMsg _Msh_gO_Found
	push IFS -f
	set -f
	IFS=",$WHITESPACE"
	for _Msh_gO_OptSpec in ${_Msh_gO_LongOpts}; do
		if same "$_Msh_gO_OptSpec" ':'; then
			_Msh_gO_NoMsg=y
			continue
		fi
		if not match "$_Msh_gO_Opt" "-${_Msh_gO_OptSpec%:}"; then
			continue
		fi

		# If the option requires an argument, test that it has one,
		# replicating the short options behaviour of 'getopts'.
		case "$_Msh_gO_OptSpec" in
		( *: )	if empty "$OPTARG"; then
				if isset _Msh_gO_NoMsg; then
					eval "${_Msh_gO_VarName}=':'"
					OPTARG="-$_Msh_gO_OptSpec"
				else
					eval "${_Msh_gO_VarName}='?'"
					echo "${ME##*/}: option requires argument: -$_Msh_gO_Opt" 1>&2
				fi
				_Msh_gO_Found=y
				break
			fi ;;
		esac
		
		eval "${_Msh_gO_VarName}=\"\$_Msh_gO_Opt\""
		_Msh_gO_Found=y
		break
	done
	pop IFS -f

	if not isset _Msh_gO_Found; then
		eval "${_Msh_gO_VarName}='?'"
		if isset _Msh_gO_NoMsg; then
			OPTARG="$_Msh_gO_Opt"
		else
			unset OPTARG
			echo "${ME##*/}: unrecognized option: -$_Msh_gO_Opt" 1>&2
		fi
	fi

	unset -v _Msh_gO_NoMsg _Msh_gO_Found _Msh_gO_Opt _Msh_gO_OptSpec
	return 0
}
