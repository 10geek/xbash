#       ____        ____            ____
#   ___/ / /_  __ __   /  ___ _ ___    /
#  ___  . __/  \ \ // _ \/ _ `/(_- `/ _ \
# ___    __/  /_\_\/_.__/\_,_//___)/_//_/
#   /_/_/
#
# xbash - an extensible framework for interactive bash shell with advanced
# completion engine.
#
# Version: 0.1.3 (2021-01-17)
#
# Copyright (c) 2020-2021 10geek
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


## Configuration variables

XBASH_CHAR_GROUP_RE='([^]['$'\t'' !"#$%'\''(),./:;?@\^`{}~&*+<=>|-][^]['$'\t'' !"#$%'\''(),./:;?@\^`{}~&*+<=>|]*[./]?|[][!"#$%'\''(),./:;?@\^`{}~]|[&*+<=>|-]+)'
XBASH_HISTCOMPLETE=1
XBASH_MENU_HEIGHT=15
XBASH_PROMPT_COMMAND=xbash_set_prompt
XBASH_PROMPT_CONF_DATETIME=1
XBASH_PROMPT_CONF_EXIT_STATUS=1
XBASH_PROMPT_CONF_JOBS=1
XBASH_PROMPT_CONF_SIGNAME=1
XBASH_PROMPT_CONF_TITLE=1
XBASH_PROMPT_CONF_TITLE_MAX_LENGTH=50
XBASH_PROMPT_TITLE_PREFIX=
XBASH_SNIPPETS=

# Paths to directories where xbash_completion_loader() function will look for
# dynamically loadable completion modules.
XBASH_COMPLETION_LOAD_DIRS=(
	~/.xbash/completions
	/etc/xbash/completions
	/usr/local/share/xbash/completions
	/usr/share/xbash/completions
)
if [[ "${BASH_SOURCE[0]}" = /usr/local/* ]]; then
	XBASH_COMPLETION_LOAD_DIRS+=(/usr/local/share/xbash/base-completions)
elif [ "${BASH_SOURCE[0]::${#HOME} + 1}" = "$HOME/" ]; then
	XBASH_COMPLETION_LOAD_DIRS+=(~/.xbash/base-completions)
else
	XBASH_COMPLETION_LOAD_DIRS+=(/usr/share/xbash/base-completions)
fi


## Predefined variables

XBASH_VERSION=0.1.3
XBASH_DEFAULT_IFS=$IFS
XBASH_PROMPT_PRE=
XBASH_PROMPT_PS1=
XBASH_PROMPT_TITLE=

# An array whose keys are signal numbers and whose values are their names.
eval "XBASH_SIGNALS=($(kill -l | LC_ALL=C awk -- '{
	for(i = 1; i <= NF; i += 2) {
		j = i + 1
		gsub(/[^0-9]/, "", $i)
		if($i == "" || index($j, "\47") || !sub(/^SIG/, "", $j)) continue
		print "[" $i "]=\47" $j "\47"
	}
}'))"


## Common functions

# Usage: xbash_awk awk_program [<arg>] ...
# Executes an AWK program with pre-declared functions and variables described below.
#
# List of pre-declared functions and variables:
#
# xbash_err(message [, exit_code])
# Outputs error message to standard error and causes AWK to exit with
# `exit_code`, if specified.
#
# xbash_escape(string [, no_l_quote [, no_r_quote [, string_escaping]]])
# Escapes a string to be used as an argument in bash command. The `string` can
# contain any characters, with the exception of the NULL byte.
# `no_l_quote` specifies not to output a quote at the left of string.
# `no_r_quote` specifies not to output a quote at the right of string.
# `string_escaping` specifies the following types of escaping:
# 0 - Hello\ world\!
# 1 - "Hello world\!"
# 2 - 'Hello world!' (default)
# 3 - $'Hello world!'
#
# xbash_levenshtein(str1, str2 [, cost_ins [, cost_rep [, cost_del]]])
# Returns the Levenshtein distance between strings `str1` and `str2`, which is
# the the minimum number of characters to insert, replace, or delete in order
# to convert `str1` to `str2`.
#
# xbash_mbchrpos(string, i)
# Returns the position of the i-th character in the UTF-8 `string`. The function
# sets the variables RSTART (which is equal to the return value) and RLENGTH,
# which is equal to the character length in bytes.
#
# xbash_mblength(string)
# Returns the number of characters in the UTF-8 `string`.
#
# xbash_ml2ol(string)
# Converts a multiline `string` to a single line, converting "\e" to "\e\e"
# and "\n" to "\en".
#
# xbash_ol2ml(string)
# Decodes the `string` encoded by the xbash_ml2ol() function.
#
# xbash_startswith(string, substring)
# Checks whether the `string` starts with the specified `substring`.
#
# argc
# Number of passed arguments (including the executable name, which is in ARGV[0]).
#
# xbash_ord[]
# An array in which the keys are ASCII + Extended ASCII characters, without
# a NULL byte, and the values are their decimal codes.
#
# xbash_re_bash_special_char
# A regular expression that matches a character that has a special meaning in bash.
#
# xbash_re_bash_nonspecial_char
# A regular expression that matches a character that has no special meaning in bash.
#
# xbash_re_printable_char
# A regular expression that matches a printable UTF-8 character.
xbash_awk() {
	LC_ALL=C awk -f <(printf %s '
	function xbash_err(message, exit_code,    OLD_ORS) {
		OLD_ORS = ORS; ORS = ""
		if(xbash_err__is_term == -1) xbash_err__is_term = !system("[ -t 2 ]")
		if(xbash_err__is_term) message = "\33[1;31mxbash_awk:\33[22m " message "\33[0m"
		else message = "xbash: " message
		print message "\n" | "cat 1>&2"; close("cat 1>&2")
		ORS = OLD_ORS
		if(exit_code != 0 || exit_code != "") {
			xbash_err__exit_code = exit_code
			exit exit_code
		}
		return 1
	}
	function xbash_escape(string, no_l_quote, no_r_quote, string_escaping,    i, max_i, re, char_enc, substr1, substr2, quote, is_last_char_printable, escaped_string, OLD_RSTART, OLD_RLENGTH) {
		OLD_RSTART = RSTART; OLD_RLENGTH = RLENGTH
		if(string_escaping == "") string_escaping = 2
		escaped_string = ""
		if(string_escaping == 1) quote = "\""
		else if(string_escaping == 2) quote = "\47"
		else quote = ""
		is_last_char_printable = 1
		gsub(/\0/, "", string)
		while(string != "") {
			if(match(string, xbash_re_printable_char "+")) {
				is_last_char_printable = 1
				if(RSTART == 1) substr1 = ""
				else substr1 = substr(string, 1, RSTART - 1)
				substr2 = substr(string, RSTART, RLENGTH)
				string = substr(string, RSTART + RLENGTH)
			} else {
				is_last_char_printable = 0
				substr1 = string
				string = substr2 = ""
			}
			if(RSTART != 1) {
				if(no_l_quote || escaped_string != "")
					escaped_string = escaped_string quote
				if(string_escaping != 3) escaped_string = escaped_string "$\47"
				max_i = length(substr1)
				for(i = 1; i <= max_i; i++) {
					char_enc = xbash_ord[substr(substr1, i, 1)]
					if(char_enc == 7) char_enc = "\\a"
					else if(char_enc == 8) char_enc = "\\b"
					else if(char_enc == 9) char_enc = "\\t"
					else if(char_enc == 10) char_enc = "\\n"
					else if(char_enc == 11) char_enc = "\\v"
					else if(char_enc == 12) char_enc = "\\f"
					else if(char_enc == 13) char_enc = "\\r"
					else if(char_enc == 27) char_enc = "\\e"
					else char_enc = "\\" sprintf("%o", char_enc)
					escaped_string = escaped_string char_enc
				}
				if(string_escaping != 3) escaped_string = escaped_string "\47"
				if(is_last_char_printable) escaped_string = escaped_string quote
			} else if(escaped_string == "" && !no_l_quote)
				escaped_string = quote
			if(string_escaping == 2) {
				gsub(/\47/, "\47\134\47\47", substr2)
				escaped_string = escaped_string substr2
			} else while(substr2 != "") {
				if(!string_escaping) re = xbash_re_bash_special_char
				else if(string_escaping == 1) re = "[!\"$\\\\`]"
				else if(string_escaping == 3) re = "[\47\\\\]"
				if(match(substr2, re "+")) {
					if(RSTART != 1) escaped_string = escaped_string substr(substr2, 1, RSTART - 1)
					max_i = RSTART + RLENGTH - 1
					for(i = RSTART; i <= max_i; i++)
						escaped_string = escaped_string "\\" substr(substr2, i, 1)
					substr2 = substr(substr2, RSTART + RLENGTH)
				} else {
					escaped_string = escaped_string substr2
					substr2 = ""
				}
			}
		}
		if(string_escaping == 3) {
			if(!no_l_quote) escaped_string = "$\47" escaped_string
			if(!no_r_quote) escaped_string = escaped_string "\47"
		} else if(escaped_string == "") {
			if(quote == "") escaped_string = "\47\47"
			else {
				if(!no_l_quote) escaped_string = quote
				if(!no_r_quote) escaped_string = escaped_string quote
			}
		} else if(!no_r_quote == is_last_char_printable)
			escaped_string = escaped_string quote
		RSTART = OLD_RSTART; RLENGTH = OLD_RLENGTH
		return escaped_string
	}
	function xbash_levenshtein(str1, str2, cost_ins, cost_rep, cost_del,    str1_len, str2_len, matrix, i, j, x, y, z) {
		if(cost_ins == "") cost_ins = 1
		if(cost_rep == "") cost_rep = 1
		if(cost_del == "") cost_del = 1
		str1_len = length(str1)
		str2_len = length(str2)
		if(str1_len == 0) return str2_len * cost_ins
		if(str2_len == 0) return str1_len * cost_del
		matrix[0, 0] = 0
		for(i = 1; i <= str1_len; i++) {
			matrix[i, 0] = i * cost_del
			for(j = 1; j <= str2_len; j++) {
				matrix[0, j] = j * cost_ins
				x = matrix[i - 1, j] + cost_del
				y = matrix[i, j - 1] + cost_ins
				z = matrix[i - 1, j - 1] + (substr(str1, i, 1) == substr(str2, j, 1) ? 0 : cost_rep)
				x = x < y ? x : y
				matrix[i, j] = x < z ? x : z
			}
		}
		return matrix[str1_len, str2_len]
	}
	function xbash_mbchrpos(string, i,    l, char_ord) {
		i += 0; l = length(string)
		if(i < 1 || i > l) {
			RSTART = 0; RLENGTH = -1
			return 0
		}
		RLENGTH = 0
		for(RSTART = 1; RSTART <= l; RSTART++) {
			char_ord = xbash_ord[substr(string, RSTART, 1)]
			if((char_ord < 128 || char_ord > 191) && --i == 0) {
				if(char_ord < 128) RLENGTH = 1
				else if(char_ord < 224) RLENGTH = 2
				else if(char_ord < 240) RLENGTH = 3
				else if(char_ord < 248) RLENGTH = 4
				else RLENGTH = 1
				break
			}
		}
		if(!RLENGTH) {
			RSTART = 0; RLENGTH = -1
		} else if(RSTART + RLENGTH - 1 > l) RLENGTH = 1
		else if(RLENGTH > 1) {
			for(i = RSTART + 1; i < RSTART + RLENGTH; i++) {
				char_ord = xbash_ord[substr(string, i, 1)]
				if(char_ord < 128 || char_ord > 191) {
					RLENGTH = 1
					break
				}
			}
		}
		return RSTART
	}
	function xbash_mblength(string) {
		gsub(/[^\1-\177\300-\367]/, "", string)
		return length(string)
	}
	function xbash_ml2ol(string) {
		gsub(/\33/, "\33\1", string)
		gsub(/\n/, "\33\2", string)
		return string
	}
	function xbash_ol2ml(string) {
		gsub(/\33\2/, "\n", string)
		gsub(/\33\1/, "\33", string)
		return string
	}
	function xbash_startswith(string, substring) {
		return substring == "" || substr(string, 1, length(substring)) == substring
	}
	BEGIN {
		argc = ARGC; ARGC = 1
		xbash_err__is_term = -1
		for(xbash_ord[""] = 1; xbash_ord[""] < 256; xbash_ord[""]++)
			xbash_ord[sprintf("%c", xbash_ord[""])] = xbash_ord[""]
		delete xbash_ord[""]
		xbash_re_bash_special_char = "][\t\n !\"#$&\47()*;<>?\\\\^`{|}~"
		xbash_re_bash_nonspecial_char = "[^" xbash_re_bash_special_char "]"
		xbash_re_bash_special_char = "[" xbash_re_bash_special_char "]"
		xbash_re_printable_char = "([\40-\176]|[\302-\337][\200-\277]|\340[\240-\277][\200-\277]|[\341-\354\356\357][\200-\277]{2}|\355[\200-\237][\200-\277]|\360[\220-\277][\200-\277]{2}|[\361-\363][\200-\277]{3}|\364[\200-\217][\200-\277]{2})"
	}' "$1") -- "${@:2}"
}

# Usage: xbash_err [<err_message>] [<print_traceback>]
# Outputs error message to standard error and outputs stack trace if
# `print_traceback` argument is specified and is not equal to 0.
xbash_err() {
	local print_traceback c_bold c_normal c_reset caller i
	[ -t 2 ] && { c_bold='\e[1;31m'; c_normal='\e[0;31m'; c_reset='\e[0m'; }
	print_traceback=$2
	if [ -z "$print_traceback" ]; then
		print_traceback=0
	elif [ "$print_traceback" != 0 ]; then
		print_traceback=1
	fi
	[ -n "$1" ] && {
		[ -n "${FUNCNAME[1]+:}" ] && {
			if [ "${FUNCNAME[1]}" = source ]; then
				if [ "${BASH_SOURCE[1]}" = "${BASH_SOURCE[0]}" ]; then
					caller=xbash
				else
					caller=${BASH_SOURCE[1]}
				fi
			else
				caller=${FUNCNAME[1]}
			fi
			[ -n "$caller" ] && printf -v caller "$c_bold%q: " "$caller"
		}
		printf "%s$c_normal%s$c_reset\\n" "$caller" "$1" >&2
	}
	[ $print_traceback -eq 1 ] && xbash_traceback 1
	return 1
}

# Usage: xbash_traceback [<skip_last>]
# Outputs stack trace to standard error. If `skip_last` argument is specified,
# the number of recent calls specified in it will be excluded from output.
xbash_traceback() {
	local c_bold c_normal c_reset i first_call_idx skip_last=1
	[ -t 2 ] && { c_bold='\e[1;31m'; c_normal='\e[0;31m'; c_reset='\e[0m'; }
	[ $# -ne 0 ] && skip_last=$((skip_last + $1))
	[ ${#FUNCNAME[@]} -gt $skip_last ] || return
	{
		printf "$c_normal%s" 'Traceback (most recent call last):'
		first_call_idx=$((${#FUNCNAME[@]} - 1))
		for ((i = first_call_idx; i >= skip_last; i--)); do
			printf "\\n  Line $c_bold%-4s$c_normal : " "${BASH_LINENO[i]}"
			if [ "${FUNCNAME[i]}" = source ]; then
				printf "Source $c_bold%q$c_normal" "${BASH_SOURCE[i]}"
			else
				printf "Call $c_bold%q$c_normal defined in $c_bold%q$c_normal" \
					"${FUNCNAME[i]}" "${BASH_SOURCE[i]}"
			fi
		done
		printf "$c_reset\\n"
	} >&2
	return 0
}

# Usage: xbash_set_errors_tracing
# Sets an ERR trap that outputs a command, its exit code, and call stack when
# any command exits with a non-zero exit code.
xbash_set_errors_tracing() {
	trap 'xbash_err "command \`$BASH_COMMAND\` exited with code $?" 1' ERR
}

# Usage: xbash_set_exit_status <exit_status>
# This is a helper function that sets the exit status specified in the
# `exit_status` argument.
xbash_set_exit_status() { return "$1"; }

# Usage xbash_set_dircolors [<file>] ...
xbash_set_dircolors() {
	local file retval=0
	[ -n "${LS_COLORS+:}" ] && return 0
	xbash_checkutil -s dircolors || return 1
	[ $# -eq 0 ] && set -- ~/.dircolors ~/.dir_colors /etc/DIR_COLORS
	for file in "$@"; do
		[ -f "$file" ] || continue
		eval " $(dircolors -b -- "$file" && printf \\n%s 'return 0')"
	done
	eval " $(dircolors -b && :; printf \\n%s "return $?")"
}

# Usage: xbash_get_cursor_pos
# Gets the current cursor coordinates and outputs them to standard output.
xbash_get_cursor_pos() {
	local coords
	IFS=\; read -rsp $'\e[6n' -dR -a coords < /dev/tty
	printf %s\\n "${coords[-1]//[!0-9]/}" "${coords[-2]//[!0-9]/}"
}

# Usage: xbash_pathvarmunge <var_name> <path> [after]
# Adds the path `path` to the beginning of the `var_name` variable value, or
# to the end if `after` is specified.
xbash_pathvarmunge() {
	[ -z "$2" ] && return
	if [ "$2" = / ]; then
		eval "set -- \"\$$1\" \"\$@\""
	else
		eval "set -- \"\$$1\" \"\$1\" \"\${2%/}\" \"\${@:3}\""
	fi
	case ":$1:" in
	*:"$3":*) ;;
	::) eval "$2=\$3";;
	*)
		if [ "$4" = after ]; then
			eval "$2=\$1:\$3"
		else
			eval "$2=\$3:\$1"
		fi
		;;
	esac
}

# Usage: xbash_help [<function_name>]
# Outputs help for functions from the comments. If the `function_name`
# argument is specified, it outputs help for the specified function. If the
# function with the specified name exists, it returns 0, otherwise it returns 1.
xbash_help() {
	LC_ALL=C awk -- 'BEGIN {
		state = is_found = 0
		is_func_name_specified = ARGC > 1
		is_term = !system("[ -t 1 ]")
		ARGC = 1
	} {
		if(!sub(/^# ?/, "") || substr($0, 1, 1) == "#") {
			if(state && is_func_name_specified) exit
			state = 0
		} else if(state) {
			if($0 != "") printf("%4s", "")
			print $0
		} else {
			if(!sub(/^Usage:[\t ]*/, "") || !match($0, /^[A-Za-z_][A-Za-z0-9_]*/)) next
			if(is_func_name_specified) {
				func_name = substr($0, RSTART, RLENGTH)
				if(func_name != ARGV[1]) next
			}
			if(!state && is_found) print ""
			state = is_found = 1
			if(is_term) print "\33[1m" $0 "\33[0m"
			else print $0
		}
	} END { if(!is_found) exit 1 }' "$@" < "${BASH_SOURCE[0]}" ||
	xbash_err "help for \`$1' is not found"
}

# Usage: xbash_checkutil [-s] [<utility>] ...
# Checks the availability of the utilities listed in the arguments. Option -s
# means not to display a message with a list of missing utilities. Returns 1
# if one of the utilities listed in the arguments is not found.
xbash_checkutil() {
	local silent=0 util util_path not_found_utils IFS
	IFS=$XBASH_DEFAULT_IFS
	[ "$1" = -s ] && {
		silent=1
		shift
	}
	[ "$1" = -- ] && shift
	for util in $*; do
		{
			util_path=$(command -v -- "$util") &&
			[ -n "$util_path" ]
		} ||
			not_found_utils+=', '$util
	done
	not_found_utils=${not_found_utils:2}
	[ -z "$not_found_utils" ] || {
		not_found_utils=${not_found_utils# }
		[ $silent -eq 0 ] &&
			xbash_err "\`$(printf %s "$not_found_utils" | sed 's/, /'\'', `/g; s/\(.*\), /\1 and /')' is not found in system, PATH=$PATH" 1
		return 1
	}
}

# Usage: xbash_semver_match [<version>] <range_set>
# Compares `version` with the specified `range_set` in the same way as
# npm-semver (see https://docs.npmjs.com/misc/semver) in accordance with the
# Semantic Versioning specification (see https://semver.org/). If the `version`
# argument is specified, it returns 0 if the `version` corresponds to the range
# specified in the `range_set` argument, otherwise it returns 1. If the
# `version` argument is omitted, it reads the list of versions line by line
# from standard input and outputs to standard output those that match the
# specified range.
xbash_semver_match() {
	local awk_code
	awk_code='function version_compare(ver1, ver2,    retval, i, compchr1, compchr2, compstr1, compstr2, compnum1, compnum2, OLD_RSTART, OLD_RLENGTH) {
		OLD_RSTART = RSTART; OLD_RLENGTH = RLENGTH
		retval = 0
		sub(/\+.*/, "", ver1); sub(/\+.*/, "", ver2)
		while(ver1 != "" || ver2 != "") {
			if(match(ver1, /[0-9]+/)) {
				if(RSTART == 1) compstr1 = ""
				else compstr1 = substr(ver1, 1, RSTART - 1)
				compnum1 = substr(ver1, RSTART, RLENGTH)
				sub(/^0+/, "", compnum1)
				compnum1 += 0
				ver1 = substr(ver1, RSTART + RLENGTH)
			} else {
				compstr1 = ver1
				compnum1 = ""
				ver1 = ""
			}
			if(match(ver2, /[0-9]+/)) {
				if(RSTART == 1) compstr2 = ""
				else compstr2 = substr(ver2, 1, RSTART - 1)
				compnum2 = substr(ver2, RSTART, RLENGTH)
				sub(/^0+/, "", compnum2)
				compnum2 += 0
				ver2 = substr(ver2, RSTART + RLENGTH)
			} else {
				compstr2 = ver2
				compnum2 = ""
				ver2 = ""
			}
			if(compstr1 == "") {
				if(compnum1 == "" && compnum2 == 0 && compstr2 == ".") { continue }
				if(compstr2 != "") retval = 1
			} else if(compstr2 == "") {
				if(compnum2 == "" && compnum1 == 0 && compstr1 == ".") { continue }
				retval = -1
			}
			if(retval) { break }
			i = 1; while(1) {
				compchr1 = substr(compstr1, i, 1)
				compchr2 = substr(compstr2, i, 1)
				if(compchr1 == "") {
					if(compchr2 == "") { break }
					retval = -1
				} else if(compchr2 == "") retval = 1
				if(retval) { break }
				if(compchr1 < compchr2) retval = -1
				else if(compchr1 > compchr2) retval = 1
				if(retval) { break }
				i++
			}
			if(retval) { break }
			if(compnum1 == "") {
				if(compnum2 == "") { break }
				retval = -1
			} else if(compnum2 == "") retval = 1
			if(retval) { break }
			if(compnum1 < compnum2) retval = -1
			else if(compnum1 > compnum2) retval = 1
			if(retval) { break }
		}
		RSTART = OLD_RSTART; RLENGTH = OLD_RLENGTH
		return retval
	}
	'
	if [ "${FUNCNAME[1]}" = xbash_version_compare ]; then
		awk_code+='
		function get_cond_result(ver1, op, ver2,    result) {
			result = version_compare(ver1, ver2)
			if(op == "lt") return result < 0
			if(op == "le") return result <= 0
			if(op == "gt") return result > 0
			if(op == "ge") return result >= 0
			if(op == "eq") return result == 0
			if(op == "neq") return result != 0
		}
		BEGIN {
			if(argc > 3) exit !get_cond_result(ARGV[1], ARGV[2], ARGV[3])
			if(argc != 3) exit 1
		} { if(get_cond_result($0, ARGV[1], ARGV[2])) print $0 }'
	else
		awk_code+='function semver_match(version, range_set, silent,    pre_part, has_pre_part, cond_result, group_match, op, pos, i, j) {
			if(range_set != semver_match___last_range_set) {
				semver_match___last_range_set = range_set
				semver_match__get_conds(range_set, semver_match___conds)
			}
			if(semver_match___conds["err"]) {
				if(!silent) xbash_err("xbash_semver_match: invalid range set: `" semver_match___last_range_set "\47")
				return 0
			}
			if(version !~ /^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$/) return 0
			sub(/^v/, "", version); sub(/\+.*/, "", version)
			pos = index(version, "-")
			if(pos) {
				has_pre_part = 1
				pre_part = substr(version, pos)
				version = substr(version, 1, pos - 1)
			} else {
				has_pre_part = 0
				pre_part = ""
			}
			for(i = 1; i <= semver_match___conds[0]; i++) {
				group_match = has_pre_part ? -1 : 1
				for(j = 1; j <= semver_match___conds[i, 0]; j++) {
					if(has_pre_part && (semver_match___conds[i, j, "p"] == "" || semver_match___conds[i, j, "v"] != version)) continue
					op = semver_match___conds[i, j, "o"]
					cond_result = version_compare(version pre_part, semver_match___conds[i, j, "v"] semver_match___conds[i, j, "p"])
					if(op == "<") cond_result = cond_result < 0
					else if(op == "<=") cond_result = cond_result <= 0
					else if(op == ">") cond_result = cond_result > 0
					else if(op == ">=") cond_result = cond_result >= 0
					else if(op == "=") cond_result = cond_result == 0
					if(group_match < 0) group_match = cond_result
					else if(!cond_result) { group_match = 0; break }
				}
				if(group_match > 0) return 1
			}
			return 0
		}
		function semver_match__get_conds(range_set, conds,    i, j, range, pos, op, range_ge_old, range_lt_old, range_pre_part_old) {
			range_ge_old = semver_match___range_ge
			range_lt_old = semver_match___range_lt
			range_pre_part_old = semver_match___range_pre_part
			range_set = range_set " "
			gsub(/[\t\n\v\f\r ]+/, " ", range_set)
			split("", conds, ":")
			conds[0] = conds["err"] = 0
			do {
				i = ++conds[0]; j = 0
				pos = index(range_set, "||")
				if(pos) {
					range = substr(range_set, 1, pos - 1)
					range_set = substr(range_set, pos + 2)
				} else {
					range = range_set
					range_set = ""
				}
				sub(/^ /, "", range); sub(/ $/, "", range)
				pos = index(range, " - ")
				if(pos) {
					if(!semver_match___get_range(substr(range, 1, pos - 1))) {
						conds["err"] = 1; break
					}
					if(semver_match___range_ge != "") {
						conds[i, ++j, "o"] = ">="
						conds[i, j, "v"] = semver_match___range_ge
						conds[i, j, "p"] = semver_match___range_pre_part
					}
					if(!semver_match___get_range(substr(range, pos + 3))) {
						conds["err"] = 1; break
					}
					if(semver_match___range_ge != "") {
						if(semver_match___range_lt == "") {
							conds[i, ++j, "o"] = "<="
							conds[i, j, "v"] = semver_match___range_ge
							conds[i, j, "p"] = semver_match___range_pre_part
						} else {
							conds[i, ++j, "o"] = "<"
							conds[i, j, "v"] = semver_match___range_lt
							conds[i, j, "p"] = ""
						}
					}
				} else {
					while(range != "") {
						op = substr(range, 1, 2)
						pos = 3
						if(op == "^=") op = "^"
						else if(op == "~=" || op == "~>") op = "~"
						else if(op != "<=" && op != ">=") {
							op = substr(op, 1, 1); pos = 2
							if(op != "^" && op != "~" && op != "<" && op != ">" && op != "=") { op = "="; pos = 1 }
						}
						if(pos > 1) {
							if(substr(range, pos, 1) == " ") pos++
							range = substr(range, pos)
						}
						sub(/^=+/, "", range)
						if(range == "") pos = 1
						else pos = index(range, " ")
						if(pos == 1 || !semver_match___get_range(pos ? substr(range, 1, pos - 1) : range, (op == "^" || op == "~") ? op : "")) {
							conds["err"] = 1; break
						}
						if(pos) range = substr(range, pos + 1)
						else range = ""
						if(op == "^" || op == "~") op = "="
						if(semver_match___range_ge == "") { continue }
						else if(semver_match___range_lt == "" || op == "<" || op == ">=") {
							conds[i, ++j, "o"] = op
							conds[i, j, "v"] = semver_match___range_ge
							conds[i, j, "p"] = semver_match___range_pre_part
						} else if(op == ">") {
							conds[i, ++j, "o"] = ">="
							conds[i, j, "v"] = semver_match___range_lt
							conds[i, j, "p"] = ""
						} else {
							if(op == "=") {
								conds[i, ++j, "o"] = ">="
								conds[i, j, "v"] = semver_match___range_ge
								conds[i, j, "p"] = semver_match___range_pre_part
							}
							conds[i, ++j, "o"] = "<"
							conds[i, j, "v"] = semver_match___range_lt
							conds[i, j, "p"] = ""
						}
					}
				}
				conds[i, 0] = j
			} while(range_set != "")
			semver_match___range_ge = range_ge_old
			semver_match___range_lt = range_lt_old
			semver_match___range_pre_part = range_pre_part_old
			return !conds["err"]
		}
		function semver_match___get_range(version, range_prefix,    parts, parts_len, i, pos) {
			if(version !~ /^v?([Xx*]|0|[1-9][0-9]*)(\.([Xx*]|0|[1-9][0-9]*)(\.([Xx*]|0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?)?)?$/) return 0
			sub(/^v/, "", version); sub(/\+.*/, "", version)
			pos = index(version, "-")
			if(pos) {
				semver_match___range_pre_part = substr(version, pos)
				version = substr(version, 1, pos - 1)
			} else semver_match___range_pre_part = ""
			parts_len = split(version, parts, "\\.")
			for(i = 1; i <= 3; i++) {
				if(i > parts_len) parts[i] = 0
				else if(parts[i] == "X" || parts[i] == "x" || parts[i] == "*") {
					parts[i] = 0
					parts_len = i - 1
				}
			}
			if(parts_len != 3) semver_match___range_pre_part = ""
			if(range_prefix == "^") {
				if(parts[1] == 0 && parts_len > 1) {
					if(parts[2] == 0 && parts_len == 3) parts_len = 3
					else parts_len = 2
				} else if(parts_len) parts_len = 1
			} else if(range_prefix == "~" && parts_len == 3) parts_len = 2
			if(!parts_len)
				semver_match___range_ge = semver_match___range_lt = ""
			else {
				semver_match___range_ge = parts[1] "." parts[2] "." parts[3]
				if(parts_len == 1)
					semver_match___range_lt = (parts[1] + 1) ".0.0"
				else if(parts_len == 2)
					semver_match___range_lt = parts[1] "." (parts[2] + 1) ".0"
				else if(parts_len == 3)
					semver_match___range_lt = ""
			}
			return 1
		}
		BEGIN {
			semver_match___last_range_set = ""
			semver_match___conds[0] = 1
			semver_match___conds[1, 0] = 0
			semver_match___conds["err"] = 0
			if(argc > 2) exit !semver_match(ARGV[1], ARGV[2])
			if(argc != 2) exit 1
			semver_match__get_conds(ARGV[1], semver_match___conds)
			if(semver_match___conds["err"]) xbash_err("xbash_semver_match: invalid range set: `" ARGV[1] "\47", 1)
		} { if(semver_match($0, ARGV[1], 1)) print $0 }'
	fi
	xbash_awk "$awk_code" "$@"
}

# Usage: xbash_version_compare [<version1>] <operator> <version2>
# If `version1` is specified, it compares it with `version2` using specified
# comparison `operator` and returns 0 if the condition is true, otherwise it
# returns 1. If `version1` argument is omitted, it reads the list of versions
# line by line from standard input and outputs to standard output those that
# satisfy the condition. The function is compatible with Semantic Versioning
# (see https://semver.org/), but can also be used with any versions.
#
# Operators (similar to those used in the "test" shell built-in):
# lt (<), le (<=), gt (>), ge (>=), eq (==), neq (!=).
xbash_version_compare() { xbash_semver_match "$@"; }

# Usage: xbash_is_func_self_invoked
# Returns 0 if called inside a self-invoked function, and 1 otherwise.
xbash_is_func_self_invoked() {
	local func
	[ -z "${FUNCNAME[1]+:}" ] && {
		xbash_err 'can only be called from a function'
		return 1
	}
	for func in "${FUNCNAME[@]:2}"; do
		[ "$func" = "${FUNCNAME[1]}" ] && return 0
	done
	return 1
}

# Usage: xbash_includedirs [<directory>] ...
# Includes all files in the specified directories. Returns 1 if an error
# occurred while including one of the files. The function ignores the files
# specified in the XBASH_INCLUDES_BLACKLIST_GLOB variable. It can be declared,
# for example, in ~/.bashrc or /etc/xbashrc file.
# Example: XBASH_INCLUDES_BLACKLIST_GLOB='@(/etc/xbash/file|/usr/share/xbash/completions/file|~/.xbash/file)'
xbash_includedirs() {
	local _file _has_errors=0
	while [ $# -ne 0 ]; do
		[ -d "$1" ] && for _file in "$1"/*; do
			{
				[[ "$_file" != $XBASH_INCLUDES_BLACKLIST_GLOB ]] && {
					[[ "$_file" != "$HOME"/* ]] ||
					[[ "~/${_file:${#HOME} + 1}" != $XBASH_INCLUDES_BLACKLIST_GLOB ]]
				} && [ -f "$_file" ] && [ -r "$_file" ]
			} || continue
			. "$_file" || {
				_has_errors=1
				xbash_err "an error occurred while loading file \`$_file'" 1
			}
		done
		shift
	done
	return "$_has_errors"
}

# Usage: xbash_escape [<no_l_quote> [<no_r_quote> [<string_escaping>] [<separator>]]]] [-- [<string>] ...]
# Escapes a strings to be used as an argument in bash command. The `string` can
# contain any characters, with the exception of the NULL byte. If the `--`
# argument is omitted, then the string will be read from standard input.
# `no_l_quote` specifies not to output a quote at the left of string. Default: 0.
# `no_r_quote` specifies not to output a quote at the right of string. Default: 0.
# `string_escaping` specifies the following types of escaping:
#   0 - Hello\ world\!
#   1 - "Hello world\!"
#   2 - 'Hello world!' (default)
#   3 - $'Hello world!'
# `separator` specifies the string to use as a separator for escaped strings
# that are output to standard output. Default: " ".
xbash_escape() {
	xbash_awk 'BEGIN {
		ORS = ""
		process_argv_from = no_l_quote = no_r_quote = 0
		string_escaping = 2
		separator = " "
		for(i = 1; i < argc; i++) {
			if(ARGV[i] == "--") { process_argv_from = i + 1; break }
			else if(i == 1) no_l_quote = int(ARGV[i])
			else if(i == 2) no_r_quote = int(ARGV[i])
			else if(i == 3) string_escaping = int(ARGV[i])
			else if(i == 4) separator = ARGV[i]
		}
		if(process_argv_from) {
			for(i = process_argv_from; i < argc; i++) {
				if(i != process_argv_from) print separator
				print xbash_escape(ARGV[i], no_l_quote, no_r_quote, string_escaping)
			}
			exit
		}
		value = ""
	} {
		value = value (NR == 1 ? "" : "\n") $0
	} END {
		if(!process_argv_from) print xbash_escape(value, no_l_quote, no_r_quote, string_escaping)
	}' "$@"
}

# Usage: xbash_startswith <substring> [<string>] ...
# Outputs to standard output a strings starting with `substring`. If the
# `string` argument is omitted, then reads strings from standard input.
# Returns 1 if no string matches the `substring`.
xbash_startswith() {
	xbash_awk 'BEGIN {
		has_matches = 0
		if(argc > 2) {
			for(i = 2; i < argc; i++) {
				if(xbash_startswith(ARGV[i], ARGV[1])) {
					print ARGV[i]
					has_matches = 1
				}
			}
			exit
		}
	} {
		if(xbash_startswith($0, ARGV[1])) {
			print $0
			has_matches = 1
		}
	} END { exit !has_matches }' "$@"
}

# Usage: xbash_istartswith <substring> [<string>] ...
# Same as xbash_startswith, but performs a case-insensitive comparison.
xbash_istartswith() {
	xbash_awk 'BEGIN {
		has_matches = 0
		ARGV[1] = tolower(ARGV[1])
		if(argc > 2) {
			for(i = 2; i < argc; i++) {
				if(xbash_startswith(tolower(ARGV[i]), ARGV[1])) {
					print ARGV[i]
					has_matches = 1
				}
			}
			exit
		}
	} {
		if(xbash_startswith(tolower($0), ARGV[1])) {
			print $0
			has_matches = 1
		}
	} END { exit !has_matches }' "$@"
}

# Usage: xbash_move_substr <startswith_regexp> <var_name> [<move_to_var_name>] [<matched_str_var_name>]
# Moves a substring that matches the `startswith_regexp` regular expression from
# the beginning of the `var_name` variable to the end of the `move_to_var_name`
# variable. If the `move_to_var_name` argument is omitted, it only removes the
# substring from the `var_name` variable. If the `matched_str_var_name` argument
# is specified, it saves the matched substring to a variable with the specified name.
xbash_move_substr() {
	eval '[[ "$'"$2"'" =~ ^$1 ]]' || {
		[ -n "$4" ] && eval "$4="
		return 1
	}
	[ -n "$3" ] && eval "$3+=\${BASH_REMATCH[0]}"
	[ -n "$4" ] && eval "$4=\${BASH_REMATCH[0]}"
	eval "$2=\${$2:\${#BASH_REMATCH[0]}}"
}

# Usage: xbash_get_opts_from_man <man_section> [<man_arg>] ...
# Retrieves information about the options from the man page. If `man_section` is
# specified, it tries to get information about options from the specified
# section using the english man page, regardless of the current locale.
xbash_get_opts_from_man() {
	local command
	command='MANWIDTH=100000 MANOPTS='\''--nh --nj'\'' man "${@:2}" 2>/dev/null'
	[ -n "$1" ] && command='LC_ALL=C '$command
	eval "$command" | LC_ALL=C awk -- 'BEGIN {
		state = ARGV[1] == ""
		ARGC = 1
	} {
		if(state == 2) {
			if($0 ~ /^[^\t ]/) exit
			print $0
		} else if(state == 1) {
			if($0 !~ /^[\t ]*-/) next
			state = 2
			print $0
		} else if($0 == ARGV[1]) state = 1
	}' "$1"
}

# Usage: xbash_completion_loader [<command>] ...
# Looks for a dynamically loadable completion module in the directories
# specified in the XBASH_COMPLETION_LOAD_DIRS array for each `command` listed
# in the arguments, and, if module exists, loads it. If an error occurred while
# loading one of the modules, the function returns 1.
xbash_completion_loader() {
	local _load_dir _has_errors=0
	while [ $# -ne 0 ]; do
		case $1 in
		''|.|..|*/*) _has_errors=1; continue;;
		esac
		for _load_dir in "${XBASH_COMPLETION_LOAD_DIRS[@]}"; do
			{ [ -f "$_load_dir/$1" ] && [ -r "$_load_dir/$1" ]; } || continue
			. "$_load_dir/$1" && break
			_has_errors=1
			xbash_err "an error occurred while loading completion module \`$_load_dir/$1'" 1
		done
		shift
	done
	return "$_has_errors"
}

# Usage: xbash_get_line_completion <command_line> [<result_var_name>]
# Outputs result of the `command_line` completion to standard output, or assigns
# it to a variable named `result_var_name`, if the argument is specified. The
# variable name `result_var_name` must not have the "COMP_" prefix.
xbash_get_line_completion() {
	local \
		COMP_LINE_BEFORE COMP_LINE_REPLACE \
		COMP_CONTEXT COMP_STRING_ESCAPING COMP_UNEXPANDED COMP_RSEARCH \
		COMP_RSEARCH_DIRSONLY COMP_VALUE_BEFORE COMP_VALUE COMP_ARGC \
		COMP_ARGV=() COMP_VALUES=() COMP_NO_TRAILING_SPACE=0
	eval "$(xbash_awk '
	function move_substr(substr_length, dest) {
		if(!substr_length) return
		comp_line[dest] = comp_line[dest] substr(comp_line["unparsed"], 1, substr_length)
		comp_line["unparsed"] = substr(comp_line["unparsed"], substr_length + 1)
	}
	function move_matched(regexp, dest,    retval, OLD_RSTART, OLD_RLENGTH) {
		OLD_RSTART = RSTART; OLD_RLENGTH = RLENGTH
		retval = 0
		match(comp_line["unparsed"], "^" regexp)
		if(RLENGTH > 0) {
			retval = 1
			move_substr(RLENGTH, dest)
		}
		RSTART = OLD_RSTART; RLENGTH = OLD_RLENGTH
		return retval
	}
	function parse_string(state,    regexp) {
		while(1) {
			if(!state["string_escaping"]) {
				if(move_matched("\"", "replace")) state["string_escaping"] = 1
				else if(move_matched("\47", "replace")) state["string_escaping"] = 2
				else if(move_matched("\\$\47", "replace")) state["string_escaping"] = 3
			}
			if(!state["string_escaping"]) regexp = "(\\\\.|" xbash_re_bash_nonspecial_char ")*"
			else if(state["string_escaping"] == 1) regexp = "(\\\\.|[^\"\\\\$`])*\"?"
			else if(state["string_escaping"] == 2) regexp = "[^\47]*\47?"
			else if(state["string_escaping"] == 3) regexp = "(\\\\.|[^\47\\\\])*\47?"
			if(move_matched(regexp, "replace")) {
				if(state["string_escaping"] == 1) {
					if(comp_line["replace"] ~ /[^\\]"$/) state["string_escaping"] = 0
				} else if(state["string_escaping"] == 2) {
					if(comp_line["replace"] ~ /\47$/) state["string_escaping"] = 0
				} else if(state["string_escaping"] == 3) {
					if(comp_line["replace"] ~ /[^\\]\47$/) state["string_escaping"] = 0
				}
			} else return state["string_escaping"]
		}
	}
	function parse_string_special(state) {
		if(move_matched("`", "replace")) {
			state["is_expand_allowed"] = 0
			parse_context("command", "`")
		} else if(move_matched("\\$\\(", "replace")) {
			state["is_expand_allowed"] = 0
			parse_context("command", ")")
		} else if(move_matched("\\$", "replace")) {
			if(comp_line["unparsed"] ~ /^[0-9!#$*?@-]/ || comp_line["unparsed"] == "_" || comp_line["unparsed"] ~ /^_[^A-Za-z0-9_]/) {
				state["is_expand_allowed"] = 0
			} else if((comp_line["unparsed"] ~ /^[A-Za-z_][A-Za-z0-9_]*/ || comp_line["unparsed"] ~ /^\{[A-Za-z_][A-Za-z0-9_]*\}/) && !state["string_escaping"])
				state["is_expand_needed"] = 1
			parse_context("varname")
		} else if(move_matched("[*?]", "replace")) {
			if(!state["string_escaping"]) {
				if(comp_line["replace"] ~ /\*$/) {
					if(move_matched("\\*/?$", "replace"))
						state["rsearch"] = 1
					else if(move_matched("\\*\\*+/?$", "replace"))
						state["rsearch"] = 2
					else
						state["is_expand_needed"] = 1
					if(state["rsearch"] && comp_line["replace"] ~ /\/$/)
						state["rsearch_dirsonly"] = 1
				} else state["is_expand_needed"] = 1
			}
		} else if(move_matched("[][!^{}]", "replace")) {
			if(!state["string_escaping"] && (comp_line["replace"] !~ /\^$/ || comp_line["before"] ~ /^[\t ]*$/)) state["is_expand_allowed"] = 0
		} else if(!move_matched("~", "replace") && !sub(/^\\/, "", comp_line["unparsed"])) return 0
		return 1
	}
	function string_postprocess(state) {
		if(state["is_expand_allowed"]) {
			state["unexpanded"] = comp_line["replace"]
			if(state["string_escaping"] == 1)
				state["unexpanded"] = state["unexpanded"] "\""
			else if(state["string_escaping"])
				state["unexpanded"] = state["unexpanded"] "\47"
			if(!state["is_expand_needed"]) {
				state["value"] = state["unexpanded"]
				state["unexpanded"] = ""
				if(state["rsearch"]) sub(/\*+\/?$/, "", state["value"])
			}
		}
		if(state["value"] == "") state["value"] = "\47\47"
	}
	function parse_context(context, end_str,    state, cmd_argv, cmd_argc, end_str_len, comp_line_before_initial_len) {
		comp_line_before_initial_len = length(comp_line["before"])
		comp_line["before"] = comp_line["before"] comp_line["replace"]
		comp_line["replace"] = state["value"] = state["unexpanded"] = ""
		state["is_expand_allowed"] = 1
		cmd_argc = state["string_escaping"] = state["rsearch"] =\
		state["rsearch_dirsonly"] = state["is_expand_needed"] = 0
		if(end_str == "") end_str = ""
		end_str_len = length(end_str)
		if(context == "command") {
			context = "before_command"
			move_matched("(!*[\t ]+)*", "before")
			while(1) {
				parse_string(state)
				if(end_str_len && substr(comp_line["unparsed"], 1, end_str_len) == end_str)
					break
				else if(!parse_string_special(state)) {
					if(!(context == "before_command" && ( \
						comp_line["replace"] == "{" || \
						comp_line["replace"] == "}" || \
						comp_line["replace"] == "if" || \
						comp_line["replace"] == "elif" || \
						comp_line["replace"] == "then" || \
						comp_line["replace"] == "else" || \
						comp_line["replace"] == "while" || \
						comp_line["replace"] == "until" || \
						comp_line["replace"] == "do" || \
						comp_line["replace"] == "coproc" || \
						comp_line["replace"] == "time" \
					)) && (comp_line["unparsed"] == "" || comp_line["unparsed"] ~ /^[\t <>]/)) {
						string_postprocess(state)
						if(comp_line["replace"] == "[" && context == "before_command")
							state["value"] = "\\["
						if(comp_line["unparsed"] == "") break
						if(context == "before_command" && comp_line["replace"] !~ /^[A-Za-z_][A-Za-z0-9_]*=/)
							context = "command"
						if(context == "command" && !(comp_line["unparsed"] ~ /^[<>]/ && state["value"] ~ /^[0-9]+$/))
							cmd_argv[++cmd_argc] = state["value"]
						move_matched("[\t ]+", "replace")
					} else {
						cmd_argc = 0
						split("", cmd_argv, ":")
						context = "before_command"
						move_matched("[^<>](!*[\t ]+)*", "replace")
					}
					comp_line["before"] = comp_line["before"] comp_line["replace"]
					comp_line["replace"] = state["value"] = state["unexpanded"] = ""
					if(comp_line["unparsed"] == "") break
					state["is_expand_allowed"] = 1
					state["string_escaping"] = state["rsearch"] =\
					state["rsearch_dirsonly"] = state["is_expand_needed"] = 0
					if(move_matched("[<>]", "before")) {
						parse_context("filepath")
						move_matched("[\t ]+", "before")
					}
				}
			}
		} else if(context == "varname") {
			if(move_matched("\\{", "before")) {
				end_str = "}"
				end_str_len = 1
			}
			if(!(end_str_len && move_matched("#", "before")) && move_matched("([0-9]+|[!#$*?@-])", "replace"))
				context = "varname_special"
			if(context == "varname")
				move_matched("[A-Za-z_][A-Za-z0-9_]*", "replace")
			if(comp_line["unparsed"] == "")
				state["value"] = comp_line["replace"]
			else {
				context = "after_varname"
				comp_line["before"] = comp_line["before"] comp_line["replace"]
				comp_line["replace"] = ""
				if(end_str_len) move_matched("(\\\\.|[^}])+", "before")
			}
		} else if(context == "filepath") {
			comp_line_before_initial_len = -1
			if(move_matched("&", "before")) context = "fd"
			move_matched("[\t ]+", "before")
			while(1) {
				parse_string(state)
				if(!parse_string_special(state)) break
			}
			string_postprocess(state)
		}
		if(comp_line["unparsed"] == "") {
			if(!is_vars_set) {
				is_vars_set = 1
				comp_argc = cmd_argc
				for(i in cmd_argv) comp_argv[i] = cmd_argv[i]
				comp_context = context
				comp_string_escaping = state["string_escaping"]
				comp_unexpanded = state["unexpanded"]
				comp_rsearch = state["rsearch"]
				comp_rsearch_dirsonly = state["rsearch_dirsonly"]
				comp_value = state["value"]
			}
		} else {
			comp_line["before"] = comp_line["before"] comp_line["replace"]
			comp_line["replace"] = ""
			if(comp_line_before_initial_len >= 0) {
				comp_line["replace"] = substr(comp_line["before"], comp_line_before_initial_len + 1)
				comp_line["before"] = substr(comp_line["before"], 1, comp_line_before_initial_len)
			}
			move_substr(end_str_len, "replace")
		}
	}
	BEGIN {
		is_vars_set = 0
		comp_line["before"] = comp_line["replace"] = comp_line["unparsed"] = comp_value = ""
		while((getline) > 0)
			comp_line["unparsed"] = comp_line["unparsed"] (NR == 1 ? "" : "\n") $0
		parse_context("command")
		print "COMP_LINE_BEFORE=" xbash_escape(comp_line["before"])
		print "COMP_LINE_REPLACE=" xbash_escape(comp_line["replace"])
		print "COMP_CONTEXT=" xbash_escape(comp_context)
		print "COMP_STRING_ESCAPING=" comp_string_escaping
		print "COMP_UNEXPANDED=" xbash_escape(comp_unexpanded)
		print "COMP_RSEARCH=" comp_rsearch
		print "COMP_RSEARCH_DIRSONLY=" comp_rsearch_dirsonly
		print "COMP_VALUE=" comp_value
		print "COMP_ARGC=" comp_argc
		print "COMP_ARGV=("
		for(i = 1; i <= comp_argc; i++) print comp_argv[i]
		print ")"
	}' <<- EOF || printf %s\\n 'return 1'
	$1
	EOF
	)"

	if [ $# -gt 1 ]; then
		set -- 1 "${@:2}"
	else
		set -- 2 "${@:2}"
	fi
	if [ -n "$COMP_UNEXPANDED" ]; then
		xbash_compcontext_expand
	elif declare -F xbash_compcontext_"$COMP_CONTEXT" > /dev/null; then
		xbash_compcontext_"$COMP_CONTEXT"
	fi 2>&$1

	if [ $# -gt 1 ]; then
		eval " $2=\$COMP_LINE_BEFORE\$COMP_LINE_REPLACE"
	else
		printf %s\\n "$COMP_LINE_BEFORE$COMP_LINE_REPLACE"
	fi
}

# Usage: xbash_shell_preset [<grep_arg>] ...
# Performs the initial interactive shell configuration. If `grep_arg` arguments
# are specified, grep will be called with the passed arguments to filter the
# executed commands. This function is intended for calling it from ~/.bashrc file.
#
# Example:
# xbash_shell_preset -vF autopair
xbash_shell_preset() {
	[[ $- = *i* ]] || return 0
	[ $# -ne 0 ] && {
		eval " $(
			declare -f "${FUNCNAME[0]}" |
			LC_ALL=C awk -- 'BEGIN { state = 0 } {
				if(state == 1) print last_line
				else if(state == 2) state = 1
				else if($0 ~ /^[\t ]*\}[\t ]*;?[\t ]*$/) { state = 2; next }
				if(state) last_line = $0
			}' | grep "$@"
		)"
		return
	}

	local parent_proc_name
	parent_proc_name=$(ps -Ao pid,comm | awk -vppid="$PPID" '$1 == ppid { print $2; exit }')
	shopt -s autocd
	shopt -s checkhash
	shopt -s checkjobs
	shopt -s checkwinsize
	shopt -s extglob
	shopt -u histappend
	shopt -s nullglob
	bind 'set bind-tty-special-chars off' 2>/dev/null || stty werase undef
	bind -x '"\C-l": xbash_pre_prompt '\''printf "\\e[H\\e[2J\\e[3J"'\'
	bind -x '"\C-i": xbash_trigger_completion'
	bind -x '"\C-r": xbash_trigger_search_history reverse'
	bind -x '"\C-s": xbash_trigger_search_history'
	[ "$parent_proc_name" = mc ] || { :
		bind -x '"\"": xbash_buf autopair \" \"'
		bind -x '"'\''": xbash_buf autopair \'\'' \'\'
		bind -x '"\`": xbash_buf autopair \` \`'
		bind -x '"(": xbash_buf autopair \( \)'
		bind -x '")": xbash_buf autopair \)'
		bind -x '"[": xbash_buf autopair [ ]'
		bind -x '"]": xbash_buf autopair ]'
		bind -x '"{": xbash_buf autopair { }'
		bind -x '"}": xbash_buf autopair }'
		bind -x '"«": xbash_buf autopair « »'
		bind -x '"»": xbash_buf autopair »'
	}
	bind -x '"\C-w": xbash_buf backward-kill-group'
	bind -x '"\e\C-?": xbash_buf backward-kill-group'
	bind -x '"\e\C-h": xbash_buf backward-kill-group'
	bind -x '"\e[3;5~": xbash_buf kill-group'
	bind -x '"\ed": xbash_buf kill-group'
	bind -x '"\e[1;5D": xbash_buf backward-group'
	bind -x '"\eOd": xbash_buf backward-group'
	bind -x '"\e[1;3D": xbash_buf backward-group'
	bind -x '"\e[5D": xbash_buf backward-group'
	bind -x '"\eb": xbash_buf backward-group'
	bind -x '"\e[1;5C": xbash_buf forward-group'
	bind -x '"\eOc": xbash_buf forward-group'
	bind -x '"\e[1;3C": xbash_buf forward-group'
	bind -x '"\e[5C": xbash_buf forward-group'
	bind -x '"\ef": xbash_buf forward-group'
	bind -x '"\e.": xbash_pre_prompt '\'': "$(ls -lhA >&2)" 2>&1'\'
	bind '"\C-?": backward-delete-char'
	bind '"\C-h": backward-delete-char'
	bind '"\C-d": delete-char'
	bind '"\e[3~": delete-char'
	bind '"\e[H": beginning-of-line'
	bind '"\C-a": beginning-of-line'
	bind '"\eOH": beginning-of-line'
	bind '"\e[1~": beginning-of-line'
	bind '"\e[7~": beginning-of-line'
	bind '"\e[F": end-of-line'
	bind '"\C-e": end-of-line'
	bind '"\eOF": end-of-line'
	bind '"\e[4~": end-of-line'
	bind '"\e[8~": end-of-line'
	[ "$parent_proc_name" = mc ] || PROMPT_COMMAND=xbash_pre_prompt
	GLOBIGNORE=.:..
	TIMEFORMAT='time: %Rs, cpu: %P%%'
	export GREP_COLOR='1;33'
	xbash_set_dircolors
	xbash_set_default_menu
	alias bc='bc --mathlib'
	alias grep='grep --color=auto'
	alias ls='ls --color=auto --group-directories-first -v'
	alias lsblk='lsblk -o NAME,FSTYPE,MOUNTPOINT,LABEL,UUID,PARTUUID,MODEL,SIZE,TYPE'
	unalias mc 2>/dev/null
	return 0
}

# Usage: xbash_pre_prompt [<pre_command>] [<post_command>]
# Performs actions that must be performed before the prompt appears, such as
# executing the command specified in the XBASH_PROMPT_COMMAND variable and
# updating the values of the XBASH_PROMPT_PS1, XBASH_PROMPT_PRE and
# XBASH_PROMPT_TITLE variables. The commands specified in the `pre_command` and
# `post_command` arguments are executed before and after XBASH_PROMPT_COMMAND,
# respectively.
xbash_pre_prompt() {
	local cursor_pos exit_status=$? IFS
	IFS=$XBASH_DEFAULT_IFS
	eval " $1"
	cursor_pos=($(xbash_get_cursor_pos))
	[ ${cursor_pos[0]} -ne 1 ] && printf '\e[1;30;47m%%\e[0m\n'
	[ -n "$XBASH_PROMPT_PRE" ] && printf '\n\e[1A'
	xbash_set_exit_status $exit_status
	eval " $XBASH_PROMPT_COMMAND"
	eval " $2"
	[ -n "$XBASH_PROMPT_TITLE_PREFIX" ] &&
	if [ -n "$XBASH_PROMPT_TITLE" ]; then
		XBASH_PROMPT_TITLE=$XBASH_PROMPT_TITLE_PREFIX' :: '$XBASH_PROMPT_TITLE
	else
		XBASH_PROMPT_TITLE=$XBASH_PROMPT_TITLE_PREFIX
	fi
	[ -n "$XBASH_PROMPT_TITLE" ] && printf '\e]0;%s\7' "$XBASH_PROMPT_TITLE"
	[ -n "$XBASH_PROMPT_PS1" ] && PS1=${XBASH_PROMPT_PS1//\\/\\\\}
	[ -n "$XBASH_PROMPT_PRE" ] && printf %s\\n "$XBASH_PROMPT_PRE"
}

# Usage: xbash_set_prompt
# Generates the values of the variables XBASH_PROMPT_PRE and XBASH_PROMPT_PS1
# for their subsequent output by the xbash_pre_prompt() function in accordance
# with the configuration variables XBASH_PROMPT_CONF_*.
xbash_set_prompt() {
	local p_exstat=$? p_jobs=0 p_date p_host p_user p_pwd
	[ "$XBASH_PROMPT_CONF_EXIT_STATUS" = 0 ] && p_exstat=0
	[ "$XBASH_PROMPT_CONF_JOBS" = 0 ] || {
		p_jobs=$(jobs -p; echo .)
		p_jobs=${p_jobs//[^$'\n']}; p_jobs=${#p_jobs}
	}
	printf -v p_host %q "${HOSTNAME%%.*}"
	printf -v p_user %q "$USER"
	if [[ "$PWD" != "$HOME"* ]]; then
		printf -v p_pwd %q "$PWD"
	elif [ "$PWD" = "$HOME" ]; then
		p_pwd='~'
	else
		printf -v p_pwd '~/%q' "${PWD:${#HOME} + 1}"
	fi
	XBASH_PROMPT_PRE=$'\342\224\214'
	XBASH_PROMPT_PS1=$'\342\224\224'
	[ "$XBASH_PROMPT_CONF_DATETIME" = 0 ] || {
		printf -v p_date '%(%a %d %T)T' 2>/dev/null || p_date=$(date '+%a %d %T')
		XBASH_PROMPT_PS1+="[$p_date] "
	}
	if [ $EUID -eq 0 ]; then
		XBASH_PROMPT_PRE+=$'\e[1;31m'
		XBASH_PROMPT_PS1+='# '
	else
		XBASH_PROMPT_PRE+=$'\e[33m'
		XBASH_PROMPT_PS1+='$ '
	fi
	XBASH_PROMPT_PRE+=$p_user@$p_host$'\e[0m'
	[ "$p_jobs$p_exstat" = 00 ] || {
		XBASH_PROMPT_PRE+=' '
		[ "$p_jobs" = 0 ] || XBASH_PROMPT_PRE+=$'\e[1;37;44m '$p_jobs$' \e[0m'
		[ "$p_exstat" = 0 ] ||
		if
			[ "$XBASH_PROMPT_CONF_SIGNAME" != 0 ] &&
			[ $p_exstat -gt 128 ] && [ -n "${XBASH_SIGNALS[$p_exstat - 128]+:}" ]
		then
			XBASH_PROMPT_PRE+=$'\e[1;37;41m '"$p_exstat (${XBASH_SIGNALS[$p_exstat - 128]})"$' \e[0m'
		else
			XBASH_PROMPT_PRE+=$'\e[1;37;41m '$p_exstat$' \e[0m'
		fi
	}
	XBASH_PROMPT_PRE+=$' \e[1;34m'$p_pwd$'\e[0m'
	if [ "$XBASH_PROMPT_CONF_TITLE" = 0 ]; then
		XBASH_PROMPT_TITLE=
	else
		XBASH_PROMPT_TITLE=$p_user@$p_host
		if
			[ $XBASH_PROMPT_CONF_TITLE_MAX_LENGTH -ne 0 ] &&
			[ ${#p_pwd} -gt $XBASH_PROMPT_CONF_TITLE_MAX_LENGTH ]
		then
			XBASH_PROMPT_TITLE+=:...${p_pwd: -XBASH_PROMPT_CONF_TITLE_MAX_LENGTH + 3}
		else
			XBASH_PROMPT_TITLE+=:$p_pwd
		fi
	fi
}

# Usage: xbash_buf <command> [<command_argument>] ...
# Performs an operation on the editing buffer specified in the `command`
# argument. The behavior of the backward-group, forward-group,
# backward-kill-group, and kill-group commands is configured using the
# XBASH_CHAR_GROUP_RE configuration variable. This function is intended for
# use with `bind -x`.
#
# Possible commands:
# autopair <pair_left> [<pair_right>]
#   Adds the opening and corresponding closing character to the editing buffer.
#
# backward-group
#   Moves the cursor back to the beginning of the first group encountered.
#
# forward-group
#   Moves the cursor forward to the end of the first group encountered.
#
# backward-kill-group
#   Deletes the text before the cursor to the the beginning of the first group
#   encountered.
#
# kill-group
#   Deletes the text after the cursor to the end of the first group encountered.
xbash_buf() {
	[ "$1" = autopair ] && {
		{
			{
				[ $READLINE_POINT -ne 0 ] &&
				[ "${READLINE_LINE:$((READLINE_POINT - 1)):1}" = \\ ] &&
				set -- "$1" "$2"
			} || {
				{ [ $# -gt 2 ] && [ "$2" != "$3" ]; } ||
				[ "${READLINE_LINE:$READLINE_POINT:${#2}}" != "$2" ]
			}
		} &&
			READLINE_LINE=${READLINE_LINE::$READLINE_POINT}$2$3${READLINE_LINE:$READLINE_POINT}
		READLINE_POINT=$((READLINE_POINT + ${#2}))
		return
	}
	local substr before_pos after_pos
	before_pos=$READLINE_POINT
	after_pos=$READLINE_POINT
	case $1 in
	backward-group|backward-kill-group)
		substr=${READLINE_LINE::$READLINE_POINT}
		if [[ "$substr" =~ .*$XBASH_CHAR_GROUP_RE ]]; then
			substr=${BASH_REMATCH[0]}
			[[ "$substr" =~ $XBASH_CHAR_GROUP_RE$ ]]
			before_pos=$((${#substr} - ${#BASH_REMATCH[0]}))
		else
			before_pos=0
		fi
		[ "$1" = backward-group ] && after_pos=$before_pos
		;;
	forward-group|kill-group)
		substr=${READLINE_LINE:$READLINE_POINT}
		if [[ "$substr" =~ $XBASH_CHAR_GROUP_RE(.*) ]]; then
			after_pos=$((${#READLINE_LINE} - ${#BASH_REMATCH[-1]}))
		else
			after_pos=${#READLINE_LINE}
		fi
		[ "$1" = forward-group ] && before_pos=$after_pos
		;;
	esac
	READLINE_POINT=$before_pos
	[ "$before_pos" = "$after_pos" ] ||
	READLINE_LINE=${READLINE_LINE::before_pos}${READLINE_LINE:after_pos}
}

# Usage: xbash_trigger_completion
# Triggers a completion of the current command line. This function is intended
# for use with `bind -x`.
xbash_trigger_completion() {
	local result cursor_pos_start cursor_pos_current move_up_lines IFS
	IFS=$XBASH_DEFAULT_IFS

	cursor_pos_start=($(xbash_get_cursor_pos))
	printf %s "$XBASH_PROMPT_PS1"
	printf %s "${READLINE_LINE::$READLINE_POINT}"
	cursor_pos_current=($(xbash_get_cursor_pos))
	printf '%s\e[%d;%dH' "${READLINE_LINE:$READLINE_POINT}" "${cursor_pos_current[1]}" "${cursor_pos_current[0]}"
	move_up_lines=$((cursor_pos_current[1] - cursor_pos_start[1]))

	# HACK: bash does not restore terminal settings, changed before calling a
	# command whose execution is assigned to a key sequence via `bind -x`, in
	# case this command calls an external program and job control is enabled,
	# except command substitution cases.
	eval "$(
		source() {
			command . "$@" || return $?
			{ printf .; printf ' %q' "$@"; printf \\n; } >&3
		}
		.() { source "$@"; }
		xbash_get_line_completion "${READLINE_LINE::$READLINE_POINT}" result 3>&1 >&2
		printf 'result=%q\n' "$result"
	)" 2>&1

	READLINE_LINE=$result${READLINE_LINE:$READLINE_POINT}
	READLINE_POINT=${#result}
	if [ $move_up_lines -eq 0 ]; then
		printf '\e[2K\r'
	else
		printf '\e[2K\r\e[%dA' $move_up_lines
	fi
}

# Usage: xbash_trigger_search_history [reverse]
# Triggers a command history search to complete the current command line. This
# function is intended for use with `bind -x`.
xbash_trigger_search_history() {
	local result
	result=$(
		xbash_compgen_history | LC_ALL=C awk -- 'BEGIN {
			reverse = ARGV[1] == "reverse"
			ARGC = i = 1
		} {
			sub(/^[\t ]+/, ""); sub(/[\t ]+$/, "")
			if($0 == "") next
			if(reverse) {
				lines[i] = $0
				if($0 in dup) delete lines[dup[$0]]
				dup[$0] = i++
			} else {
				if($0 in dup) next
				dup[$0] = ""
				print $0
			}
		} END {
			if(!reverse) exit
			while(--i) if(i in lines) print lines[i]
		}' "$1" |
		xbash_menu
	) || return 1
	READLINE_LINE=$(printf %s "$result" | xbash_awk '{ print xbash_ol2ml($0) }')
	READLINE_POINT=${#READLINE_LINE}
}

# Usage: xbash_menu [<parameter>] ...
# Invokes the menu, retrieving possible values from standard input, and outputs
# selected values to standard output.
#
# Possible parameters:
# multi
#   Enable the selection of multiple values ​​with their subsequent
#   line-by-line output.
#
# Return values:
#   0 - Value selected
#   1 - Interrupted by user
#   2 - Other cases (e.g. empty input or error occured)
xbash_menu() {
	# Fallback xbash_menu() implementation
	local values
	values=$(cat)
	[ -z "$values" ] && return 2
	if [[ "$values" = *$'\n'* ]]; then
		printf \\n >&2
		printf %s\\n "$values" | head -n15 | tr -d \\33 >&2
	else
		printf %s\\n "$values"
		return 0
	fi
	return 1
}

# Usage: xbash_set_default_menu [-|+] [<name>] ...
# Configures xbash for use with one of the supported interactive terminal
# menu implementations. The function checks for supported implementations and
# uses the first one found. If the first argument is "-", then the function will
# check all implementations except those listed in the subsequent arguments. If
# the first argument is "+", then the function will only check those
# implementations that are listed in the subsequent arguments.
xbash_set_default_menu() {
	local i impls impl version
	if [ "$1" = + ]; then
		impls=("${@:2}")
	else
		impls=(fzf skim heatseeker fzy peco pick pmenu percol sentaku)
		[ "$1" = - ] && eval "impls=($(LC_ALL=C awk -- 'BEGIN {
			for(i = 1; i < ARGC && ARGV[i] != ""; i++) continue
			impls_len = i - 1
			for(i++; i < ARGC; i++) exclude[ARGV[i]] = ""
			for(i = 1; i <= impls_len; i++) {
				if(ARGV[i] in exclude) continue
				gsub(/\47/, "\47\134\47\47", ARGV[i])
				print "\47" ARGV[i] "\47"
			}
		}' "${impls[@]}" '' "${@:2}"))"
	fi
	for i in "${!impls[@]}"; do impl=${impls[i]}; case $impl in
	fzf)
		{
			xbash_checkutil -s "$impl" &&
			version=$(fzf --version | awk '{ print $1 }') &&
			[ -n "$version" ]
		} || continue
		xbash_menu() {
			local IFS XBASH_MENU_HEIGHT="$XBASH_MENU_HEIGHT" input_l1 input_l2 menu_height menu_command
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			IFS=$XBASH_DEFAULT_IFS
			menu_command=$XBASH_MENU_COMMAND
			[ "$1" = multi ] && menu_command+=' --multi'
			menu_height=($(xbash_get_cursor_pos))
			menu_height=$((LINES - menu_height[1]))
			[ $menu_height -gt $XBASH_MENU_HEIGHT ] && XBASH_MENU_HEIGHT=$menu_height
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | eval " $menu_command" || return 1
		}
		XBASH_MENU_COMMAND='\fzf --no-mouse --cycle --no-hscroll --height="$XBASH_MENU_HEIGHT" --reverse --tabstop=4 --bind="$XBASH_MENU_CONF_FZF_BINDS"'
		XBASH_MENU_CONF_FZF_BINDS=change:top$(printf ,%s \
			ctrl-z:abort \
			ctrl-w:backward-kill-word \
			ctrl-k:kill-line \
			ctrl-space:toggle+down \
			ctrl-t:toggle+down \
			ctrl-a:toggle-all \
			pgup:half-page-up \
			pgdn:half-page-down \
			shift-tab:up \
			tab:down
		)
		if xbash_semver_match "$version" '>= 0.21.0'; then
			XBASH_MENU_COMMAND+=' --info=inline'
			XBASH_MENU_CONF_FZF_BINDS+=$(printf ,%s \
				ctrl-/:abort \
				ctrl-\\:abort \
				bspace:backward-delete-char/eof \
				ctrl-h:backward-delete-char/eof \
				insert:toggle+down
			)
		else
			XBASH_MENU_COMMAND+=' --inline-info'
		fi
		;;
	skim)
		xbash_checkutil -s sk || continue
		xbash_menu() {
			local IFS XBASH_MENU_HEIGHT="$XBASH_MENU_HEIGHT" input_l1 input_l2 cursor_pos menu_height menu_command retval
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			IFS=$XBASH_DEFAULT_IFS
			menu_command=$XBASH_MENU_COMMAND
			[ "$1" = multi ] && menu_command+=' --multi'
			cursor_pos=($(xbash_get_cursor_pos))
			menu_height=$((LINES - cursor_pos[1]))
			[ $menu_height -gt $XBASH_MENU_HEIGHT ] && XBASH_MENU_HEIGHT=$menu_height
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | eval " $menu_command"
			retval=$?
			[ ${cursor_pos[0]} -ne 1 ] && printf '\e[1A' >&2
			[ $retval -eq 0 ]
		}
		XBASH_MENU_COMMAND='\sk --no-hscroll --inline-info --height="$XBASH_MENU_HEIGHT" --reverse --tabstop=4 --color=16 --bind="$XBASH_MENU_CONF_SKIM_BINDS"'
		XBASH_MENU_CONF_SKIM_BINDS=change:top$(printf ,%s \
			ctrl-/:abort \
			ctrl-\\:abort \
			ctrl-z:abort \
			bspace:if-query-empty\(abort\)+backward-delete-char \
			ctrl-h:if-query-empty\(abort\)+backward-delete-char \
			ctrl-w:if-query-empty\(abort\)+backward-kill-word \
			ctrl-left:backward-word \
			ctrl-right:forward-word \
			home:beginning-of-line \
			end:end-of-line \
			ctrl-k:kill-line \
			ctrl-space:toggle+down \
			insert:toggle+down \
			ctrl-t:toggle+down \
			ctrl-a:toggle-all \
			pgup:half-page-up \
			pgdn:half-page-down \
			shift-tab:up \
			tab:down
		)
		;;
	heatseeker)
		xbash_checkutil -s hs || continue
		xbash_menu() {
			local IFS input_l1 input_l2 cursor_pos multi=0 retval
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			IFS=$XBASH_DEFAULT_IFS
			[ "$1" = multi ] && multi=1
			cursor_pos=($(xbash_get_cursor_pos))
			[ ${cursor_pos[0]} -ne 1 ] && echo >&2
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | sed 's/$/ /' | eval " $XBASH_MENU_COMMAND" |
			LC_ALL=C awk -v multi="$multi" 'BEGIN {
				if(!multi) {
					if((getline) > 0) print substr($0, 1, length($0) - 1)
					exit
				}
			} {
				print substr($0, 1, length($0) - 1)
			} END { exit !NR }'
			retval=$?
			[ ${cursor_pos[0]} -ne 1 ] && printf '\e[1A' >&2
			[ $retval -eq 0 ]
		}
		XBASH_MENU_COMMAND='\hs'
		;;
	fzy)
		xbash_checkutil -s "$impl" || continue
		xbash_menu() {
			local IFS XBASH_MENU_HEIGHT="$XBASH_MENU_HEIGHT" input_l1 input_l2 cursor_pos retval
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			IFS=$XBASH_DEFAULT_IFS
			cursor_pos=($(xbash_get_cursor_pos))
			menu_height=$((LINES - cursor_pos[1] - 1))
			[ $menu_height -gt $XBASH_MENU_HEIGHT ] && XBASH_MENU_HEIGHT=$menu_height
			[ ${cursor_pos[0]} -ne 1 ] && echo >&2
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | eval " $XBASH_MENU_COMMAND"
			retval=$?
			[ ${cursor_pos[0]} -ne 1 ] && printf '\e[1A' >&2
			[ $retval -eq 0 ]
		}
		XBASH_MENU_COMMAND='\fzy -l "$XBASH_MENU_HEIGHT"'
		;;
	peco)
		xbash_checkutil -s "$impl" || continue
		xbash_menu() {
			local input_l1 input_l2 menu_command
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			menu_command=$XBASH_MENU_COMMAND
			[ "$1" = multi ] || menu_command+=' | head -n1; xbash_set_exit_status "${PIPESTATUS[0]}"'
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | eval " $menu_command" || return 1
		}
		XBASH_MENU_COMMAND='\peco --on-cancel error --rcfile <(printf %s "$XBASH_MENU_CONF_PECO")'
		XBASH_MENU_CONF_PECO='{
			"Keymap": {
				"ArrowLeft": "peco.BackwardChar",
				"ArrowRight": "peco.ForwardChar",
				"Home": "peco.BeginningOfLine",
				"End": "peco.EndOfLine",
				"Pgup": "peco.ScrollPageUp",
				"Pgdn": "peco.ScrollPageDown",
				"Tab": "peco.SelectDown",
				"Insert": "peco.ToggleSelectionAndSelectNext",
				"C-t": "peco.ToggleSelectionAndSelectNext",
				"C-a": "peco.InvertSelection",
				"C-/": "peco.Cancel"
			}
		}'
		;;
	pick|pmenu)
		xbash_checkutil -s "$impl" || continue
		xbash_menu() {
			local IFS input_l1 input_l2 cursor_pos values linen retval=0 IFS=$'\n'
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			IFS=$XBASH_DEFAULT_IFS
			cursor_pos=($(xbash_get_cursor_pos))
			[ ${cursor_pos[0]} -ne 1 ] && echo >&2
			values=$(printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null)
			linen=$(
				printf %s\\n "$values" | LC_ALL=C awk '{
					gsub(/[\1-\37\177]/, "")
					printf("%3d | %s\n", NR, $0)
				}' | eval " $XBASH_MENU_COMMAND"
			)
			retval=$?
			[ ${cursor_pos[0]} -ne 1 ] && printf '\e[1A' >&2
			[ $retval -ne 0 ] && return 1
			linen=${linen##*( )}; linen=${linen%% | *}
			printf %s "$values" | LC_ALL=C awk -v linen="$linen" 'NR == linen { print $0; exit }'
		}
		case $impl in
		pick) XBASH_MENU_COMMAND='\pick -SX';;
		pmenu) XBASH_MENU_COMMAND='\pmenu';;
		esac
		;;
	percol)
		xbash_checkutil -s "$impl" || continue
		xbash_menu() {
			local input_l1 input_l2 menu_command
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			menu_command=$XBASH_MENU_COMMAND
			[ "$1" = multi ] || menu_command+=' | head -n1; xbash_set_exit_status "${PIPESTATUS[0]}"'
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | eval " $menu_command" || return 1
		}
		XBASH_MENU_COMMAND='\percol'
		;;
	sentaku)
		xbash_checkutil -s "$impl" || continue
		xbash_menu() {
			local input_l1 input_l2
			IFS= read -r input_l1 || return 2
			IFS= read -r input_l2 || { printf %s\\n "$input_l1"; return 0; }
			{
				printf %s\\n "$input_l1" "$input_l2"; cat 2>/dev/null
			} | eval " $XBASH_MENU_COMMAND" | LC_ALL=C awk '{ print $0 } END {
				exit (!NR || (NR == 1 && $0 == ""))
			}'
		}
		XBASH_MENU_COMMAND='\sentaku -s line -N'
		;;
	*)
		xbash_err "unsupported interactive terminal menu implementation: \`$impl'"
		unset -v 'impls[i]'
		continue
		;;
	esac; return 0; done
	[ ${#impls} -ne 0 ] && {
		printf -v impls ', %q' "${impls[@]}"
		impls=${impls:2}
	}
	xbash_err "no available interactive terminal menu implementations were found. Please install one of the following: ${impls:-<nothing>}"
}

# Usage: xbash_parse_comp_argv <result_var_name> [<short_bool_opt_regexp>] [<short_arg_opt_regexp>] [<long_arg_opt_regexp>] [<no_split_comp_value>]
# Parses the array of arguments COMP_ARGV and returns the result to an array
# whose name is specified in the `result_var_name` argument.
# The `short_bool_opt_regexp` argument is a regular expression that matches the
# names of short boolean options that have no argument, and `short_arg_opt_regexp`
# and `long_arg_opt_regexp` matches the names of short and long (GNU-style)
# options that must have arguments. If COMP_VALUE is an option that has an
# argument and `no_split_comp_value` is not specified or is equal to 0, then
# moves the left part of the COMP_VALUE variable before the value of the option
# to the COMP_VALUE_BEFORE variable.
#
# The `result_var_name` array contains the following values:
# result_var_name[0] - number of positional arguments (which are located
#                      after options and their values), except COMP_VALUE.
# result_var_name[1] - if COMP_VALUE must be followed by the option name or part
#                      of it, it is equal to 1, otherwise it is equal to 0.
# result_var_name[2] - if COMP_VALUE is an option value, it contains the name of
#                      this option without the leading "-", otherwise it is
#                      equal to an empty string. In the first case, the function
#                      return code is 0, and in the second case it is 1.
# result_var_name[3] - if COMP_VALUE is an option that has an argument, it is
#                      equal to the position where the value of the option starts.
#
# Example (for GNU sed):
# xbash_parse_comp_argv CONTEXT '[nErsuz]' '[efl]' '(expression|file|line-length)'
# where [nErsuz] are boolean options, and [efl] and (expression|file|line-length)
# are options that must have an argument. Note that the -i and --in-place options
# have an optional argument, so they are not specified anywhere.
xbash_parse_comp_argv() {
	eval "$(xbash_awk 'BEGIN {
		short_bool_opt_regexp = short_arg_opt_regexp = long_arg_opt_regexp = ""
		no_split_comp_value = end_of_opts = is_at_opt_name = comp_value_split_pos = 0
		if(ARGV[1] == 0 || ARGV[2] !~ /^[A-Za-z_][A-Za-z0-9_]*$/) exit
		result_var_name = ARGV[2]
		if(ARGV[1] > 1 && ARGV[3] != "") short_bool_opt_regexp = "^-" ARGV[3] "*"
		else short_bool_opt_regexp = "^-"
		if(ARGV[1] > 2 && ARGV[4] != "") short_arg_opt_regexp = ARGV[4]
		if(ARGV[1] > 3 && ARGV[5] != "") long_arg_opt_regexp = "^--" ARGV[5]
		if(ARGV[1] > 4 && ARGV[6] != "") no_split_comp_value = ARGV[6] + 0
		comp_argv_end = argc - 1
		for(i = ARGV[1] + 3; i < comp_argv_end; i++) {
			if(substr(ARGV[i], 1, 1) != "-") break
			if(ARGV[i] == "--") { end_of_opts = 1; i++; break }
			if(long_arg_opt_regexp != "" && ARGV[i] ~ long_arg_opt_regexp "$")
				opt = substr(ARGV[i++], 2)
			else if(short_arg_opt_regexp != "" && ARGV[i] ~ short_bool_opt_regexp short_arg_opt_regexp "$")
				opt = substr(ARGV[i], length(ARGV[i++]), 1)
		}
		pos_args_count = comp_argv_end - i
		if(pos_args_count == -1) pos_args_count = 0
		else {
			opt = ""
			if(pos_args_count) end_of_opts = 1
			if(!end_of_opts) {
				if(match(ARGV[comp_argv_end], /^--[^=]+=/)) {
					opt = substr(ARGV[comp_argv_end], 2, RLENGTH - 2)
					comp_value_split_pos = RLENGTH
				} else if(substr(ARGV[comp_argv_end], 2, 1) != "-" && match(ARGV[comp_argv_end], short_bool_opt_regexp)) {
					opt = substr(ARGV[comp_argv_end], RLENGTH + 1, 1)
					if(opt != "") comp_value_split_pos = RLENGTH + 1
				}
				if(opt == "" && ( \
					substr(ARGV[comp_argv_end], 1, 2) == "--" || \
					ARGV[comp_argv_end] ~ short_bool_opt_regexp "$" \
				)) is_at_opt_name = 1
			}
		}
		print result_var_name "=(" pos_args_count, is_at_opt_name, xbash_escape(opt), comp_value_split_pos ")"
		if(!no_split_comp_value && comp_value_split_pos)
			print "COMP_VALUE_BEFORE+=${COMP_VALUE::" comp_value_split_pos "}; COMP_VALUE=${COMP_VALUE:" comp_value_split_pos "}"
		print "return " (opt == "")
	}' $# "$@" "${COMP_ARGV[@]}" "$COMP_VALUE")"
}

# Usage: xbash_setcomp_common [<command>] ...
# Set completion using the xbash_compspecial_common() function for commands
# listed in the arguments.
#
# The <command> argument has the following syntax:
# <command>[[;] <eval_after>]
# or
# [!]<command>
#
# If <eval_after> is specified, it will be interpreted as part of a command that
# is executed to get help of the command. The ";" character indicates to use a
# special command to get help. For example:
# 'cd; help cd | sed "/Exit Status:/q"'
# or
# 'ssh; xbash_get_opts_from_man "" 1 ssh'
#
# The "!" character before the <command> argument means not to apply a
# completion to the specified command if it is present in the following arguments.
xbash_setcomp_common() {
	eval "$(LC_ALL=C awk -- '
	function esc(str) {
		if(str !~ /^[A-Za-z0-9._-]+$/) {
			gsub(/\47/, "\47\134\47\47", str)
			str = "\47" str "\47"
		}
		return str
	}
	BEGIN {
		ORS = ""
		for(i = 1; i < ARGC; i++) {
			if(sub(/^!/, "", ARGV[i])) {
				comp_set[ARGV[i]] = ""
				continue
			}
			is_eval_after_required = 0
			if(match(ARGV[i], /(;[\t ]*|[\t ]+)/) && RSTART != 1) {
				command = substr(ARGV[i], 1, RSTART - 1)
				eval_after = substr(ARGV[i], RSTART + RLENGTH)
				if(substr(ARGV[i], RSTART, 1) == ";") {
					is_eval_after_required = 1
					help_command = ""
				} else help_command = command
			} else {
				command = ARGV[i]
				help_command = eval_after = ""
			}
			if(command == "" || command in comp_set) continue
			comp_set[command] = ""
			print "xbash_comp_" esc(command) "() { xbash_compspecial_common"
			if(is_eval_after_required || eval_after != "") print " " esc(help_command) " " esc(eval_after)
			print "; }\n"
		}
	}' "$@")"
}


## Completion generators

xbash_compgen_before_command() {
	[ $COMP_STRING_ESCAPING -eq 0 ] && {
		xbash_compgen_snippets
		[ $XBASH_HISTCOMPLETE -eq 1 ] && xbash_compgen_history | grep -vx '[A-Za-z.:_-]*'
	} | LC_ALL=C awk '{
		sub(/^[\t ]+/, ""); sub(/[\t ]+$/, "")
		if($0 == "" || $0 in dup) next
		dup[$0] = ""
		print $0 "\33"
	}'
	compgen -c | LC_ALL=C sort -u
	[ $COMP_STRING_ESCAPING -eq 0 ] && compgen -vS=
}

# Usage: xbash_compgen_snippets
# Outputs a snippets specified in the XBASH_SNIPPETS variable to standard output.
xbash_compgen_snippets() {
	xbash_awk '
	function print_str() {
		if(!sub(/[\t ]#[\t ]*$/, "", nstr[n]) || nstr[n] != "") print nstr[n]
	}
	BEGIN { n = 0 } {
		if($0 == "" || !match($0, /[^\t ]/)) next
		indent = substr($0, 1, RSTART - 1)
		gsub(/\t/, "    ", indent)
		indent = length(indent)
		$0 = substr($0, RSTART)
		if(!n) n = 1
		else if(indent > nindent[n]) n++
		else {
			print_str()
			while(n > 1 && indent < nindent[n]) {
				delete nindent[n]
				delete nstr[n]
				n--
			}
		}
		nindent[n] = indent
		if(n == 1) nstr[1] = $0
		else nstr[n] = nstr[n - 1] " " $0
	}
	END { if(n) print_str() }' <<- EOF
	$XBASH_SNIPPETS
	EOF
}

xbash_compgen_history() {
	{ HISTTIMEFORMAT=$'\36'; history; } | xbash_awk '
	function output_line() {
		if(line == "" || line in dups) return
		dups[line] = ""
		print xbash_ml2ol(line)
	}
	BEGIN { line = "" } {
		pos = index($0, "\36")
		if(pos) {
			output_line()
			line = substr($0, pos + 1)
		} else line = line "\n" $0
	} END { output_line() }'
}

# Usage: xbash_compgen_bash_completion <command> [<arg>] ...
# Outputs to standard output a values of the bash completion for specified
# command and arguments.
xbash_compgen_bash_completion() {
	[ $# -eq 0 ] && return

	local \
		IFS command compfunc completion_loader_executed oldfunc \
		COMP_CWORD COMP_KEY COMP_LINE COMP_POINT COMP_TYPE COMP_WORDS COMPREPLY=()

	declare -F _completion_loader > /dev/null || return 1

	set -- "${1##*/}" "${@:2}"
	[ -n "$1" ] || return 1

	IFS=$XBASH_DEFAULT_IFS
	oldfunc=$(declare -f _filedir _filedir_xspec)
	eval "COMP_WORDS=($(xbash_awk 'BEGIN {
		ORS = ""
		for(i = 1; i < argc; i++) {
			if(ARGV[i] == "") print " \47\47"
			else if(ARGV[i] ~ xbash_re_bash_special_char) {
				gsub(/\47/, "\47\134\47\134\134\134\47\134\47\47", ARGV[i])
				print " \134\47\47" ARGV[i] "\47\134\47"
			} else print " " ARGV[i]
		}
	}' "$@"))"
	COMP_KEY=9
	COMP_TYPE=9
	COMP_LINE=${COMP_WORDS[*]}
	COMP_POINT=${#COMP_LINE}
	COMP_CWORD=$(($# - 1))

	completion_loader_executed=0
	while :; do
		compfunc=$(complete -p -- "$1" 2>/dev/null | awk '{
			for(i = NF - 2; i > 1; i--) if($i == "-F") {
				i++
				if($i == "_minimal" || $i == "_filedir" || $i == "_filedir_xspec") next
				print $i
				exit
			}
		}')
		[ -n "$compfunc" ] && break
		if [ $completion_loader_executed -eq 0 ]; then
			_completion_loader "$1"
			completion_loader_executed=1
		else
			return 1
		fi
	done

	_filedir() { :; }
	_filedir_xspec() { :; }
	"$compfunc" "${COMP_WORDS[0]}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD - 1]}" 2>/dev/null
	eval "$oldfunc"
	[ ${#COMPREPLY[@]} -eq 0 ] ||
	printf %s\\n "${COMPREPLY[@]}" | LC_ALL=C sort -u
}

xbash_compgen_signals() {
	kill -l | LC_ALL=C awk '{
		for(i = 1; i <= NF; i += 2) {
			gsub(/[^0-9]/, "", $i)
			sig_name = toupper($(i + 1))
			sub(/^SIG/, "", sig_name)
			print $i, sig_name
		}
	}'
}

# Usage: xbash_compgen_shell_child_pid [<pid_starts_with> | <cmd_contains>]
xbash_compgen_shell_child_pid() {
	ps -Ao ppid,pid,args | xbash_awk 'BEGIN {
		search_by_comm = ARGV[1] != "" && ARGV[1] !~ /^[1-9][0-9]*$/
		if(search_by_comm) ARGV[1] = tolower(ARGV[1])
		ARGC = 1
	} {
		ppid = $1; $1 = ""
		if(!match($0, /[0-9]+/)) next
		pid = substr($0, RSTART, RLENGTH)
		ppids[pid] = ppid
		if(ppid == ARGV[2] && (search_by_comm ? index(tolower($0), ARGV[1]) : xbash_startswith(pid, ARGV[1])))
			result[pid] = substr($0, RSTART + RLENGTH)
	} END {
		pid = ARGV[3]
		while(pid != "") {
			if(ppids[pid] == ARGV[2]) {
				delete result[pid]
				break
			}
			pid = ppids[pid]
		}
		for(pid in result) printf("%-8s %s\n", pid, result[pid])
	}' "$1" $$ $BASHPID | LC_ALL=C sort -n
}

# Usage: xbash_compgen_parse_help [<starts_with>] [<match_all_short_opts>]
xbash_compgen_parse_help() {
	xbash_awk '
	function process_group(    i, opts_splitted, opts_splitted_len, group_opts_count, opt_str_len) {
		gsub(/  +/, " ", opts_descr)
		sub(/^ /, "", opts_descr); sub(/ $/, "", opts_descr)
		opt_groups[opt_groups[0], 0] = opts_count
		opt_groups[opt_groups[0], ""] = opts_descr
	}
	BEGIN {
		opt_groups[0] = has_eq_sign = context = opts_count = opts_col_width = 0
		opts_descr = ""
		if(ARGV[1] != "" && ARGV[1] !~ /^-([A-Za-z0-9!#$%\57@_]+|-?([A-Za-z0-9][A-Za-z0-9_-]*=?)?)?$/) exit
		if(!ARGV[2]) {
			starts_with = tolower(ARGV[1])
			has_eq_sign = sub(/=$/, "", starts_with)
		}
	} {
		line_has_opts = 0
		gsub(/[\1-\10\12-\37\177]/, " "); gsub(/\t/, "  "); sub(/^ +/, "")
		while((!line_has_opts || sub(/^( *, *| +(or +)?)/, "")) && match($0, \
			/^-([A-Za-z0-9!#$%\57@_]|-[A-Za-z0-9])[^][ ,:{}()<>]*( ?(\[[^]]*\]|\{[^}]*\}|\([^)]*\)|<[^>]*>)([^ ,-][^ ,]*)?)*(( [^ ,-][^ ,]*)*(  +| ?,))?/ \
		)) {
			if(context != 1) {
				if(context == 2) process_group()
				opt_groups[++opt_groups[0], 0] = opts_count = 0
				context = 1
				opts_descr = ""
			}
			line_has_opts = 1
			if(substr($0, RLENGTH, 1) == ",") RLENGTH--
			else while(substr($0, RLENGTH, 1) == " ") RLENGTH--
			opt = substr($0, 1, RLENGTH)
			$0 = substr($0, RLENGTH + 1)
			if($0 ~ /^ [^ ]+ *$/) { opt = opt $0; $0 = "" }
			gsub(/  +/, " ", opt); sub(/^ /, "", opt); sub(/ $/, "", opt)
			opt_str_len = xbash_mblength(opt)
			if(opt_str_len > 40) {
				opt_str_len = 40
				xbash_mbchrpos(opt, 37)
				opt = substr(opt, 1, RSTART + RLENGTH - 1) "..."
			}
			if(ARGV[2]) {
				if(opt !~ /^-[^-]/) continue
			} else if(starts_with != "" && ( \
				!xbash_startswith(tolower(opt), starts_with) || \
				(has_eq_sign && substr(opt, length(starts_with) + 1, 2) !~ /^[[{(<]?=/) \
			)) continue
			if(opt_str_len > opts_col_width) opts_col_width = opt_str_len
			opt_groups[opt_groups[0], ++opts_count] = opt
			opt_groups[opt_groups[0], opts_count, ""] = opt_str_len
		}
		if(!context) next
		if(line_has_opts) sub(/^ +/, "")
		if($0 != "" && substr($0, 1, 1) != "+") {
			context = 2
			opts_descr = opts_descr " " $0
		} else if(!line_has_opts) {
			process_group()
			context = 0
		}
	} END {
		if(context) process_group()
		for(i = 1; i <= opt_groups[0]; i++) {
			opts_descr = opt_groups[i, ""]
			for(j = 1; j <= opt_groups[i, 0]; j++) {
				printf("%s", opt_groups[i, j])
				if(opts_descr != "") printf("%" (opts_col_width - opt_groups[i, j, ""]) "s -- %s", "", opts_descr)
				printf("\n")
			}
		}
	}' "$1" "$2"
}


## Special completion functions

xbash_compspecial_apply_comp_values() {
	[ ${#COMP_VALUES[@]} -eq 0 ] && return
	COMP_LINE_REPLACE=$(
		xbash_awk 'BEGIN {
			ORS = ""
			if(ARGV[3]) sub(/\*+\/?$/, "", ARGV[4])
			comp_values_start_pos = length(ARGV[6]) + 1
			if(substr(ARGV[4], 1, 2) == "~/" && ENVIRON["HOME"] != "") {
				home_path = ENVIRON["HOME"] "/"
				home_len = length(home_path)
			} else home_len = 0
			argc--
			for(i = 7; i <= argc; i++) {
				if(i != 7) print " "
				if(comp_values_start_pos == 1 || xbash_startswith(ARGV[i], ARGV[6])) {
					print ARGV[4]
					ARGV[i] = substr(ARGV[i], comp_values_start_pos)
					if(ARGV[2] || ARGV[i] != "")
						print xbash_escape(ARGV[i], 1, i == argc, ARGV[2])
				} else if(home_len && substr(ARGV[5] ARGV[i], 1, home_len) == home_path)
					print "~/" xbash_escape(substr(ARGV[5] ARGV[i], home_len + 1), 0, i == argc, ARGV[2])
				else
					print xbash_escape(ARGV[5] ARGV[i], 0, i == argc, ARGV[2])
			}
			if(!ARGV[1] && !ARGV[2]) print " "
		}' \
			"$COMP_NO_TRAILING_SPACE" "$COMP_STRING_ESCAPING" "$COMP_RSEARCH" \
			"$COMP_LINE_REPLACE" "$COMP_VALUE_BEFORE" "$COMP_VALUE" "${COMP_VALUES[@]}"
	)
}

# Usage: xbash_compspecial_fs [multi|dirsonly] ...
xbash_compspecial_fs() {
	local dir result find_command post_pipe_command=xbash_menu dirsonly=0
	while [ $# -ne 0 ]; do
		case $1 in
		multi) post_pipe_command+=' multi';;
		dirsonly) dirsonly=1;;
		*) break;;
		esac
		shift
	done
	{
		[ "$COMP_LINE_REPLACE" = '~' ] ||
		[[ "$COMP_LINE_REPLACE" =~ ^~[A-Za-z%,.:@_][A-Za-z0-9%+,.:@_-]*$ ]]
	} && {
		result=$(compgen -u | xbash_istartswith "${COMP_LINE_REPLACE:1}" | LC_ALL=C sort | xbash_menu) || return
		[ "$result" = "${COMP_LINE_REPLACE:1}" ] && {
			COMP_VALUES=("$COMP_VALUE/")
			COMP_NO_TRAILING_SPACE=1
			return
		}
		COMP_LINE_REPLACE=~$(xbash_escape 0 0 0 -- "$result")
		return
	}
	[[ "$COMP_VALUE" = */* ]] && {
		dir=${COMP_VALUE%/*}
		[ -z "$dir" ] && [ "${COMP_VALUE::1}" = / ] && dir=/
	}
	if [ -z "$dir" ] || [ -d "$dir" ]; then
		if [ $COMP_RSEARCH -eq 0 ]; then
			post_pipe_command='LC_ALL=C sort | sed '\''s/^.//'\'' | '$post_pipe_command
		else
			[ $COMP_RSEARCH_DIRSONLY -ne 0 ] && dirsonly=1
			[ $dirsonly -ne 0 ] && find_command=' \( -type d -o -type l \)'
			if [ $COMP_RSEARCH -eq 2 ]; then
				find_command='find ./.'$find_command
				find_command+=' \( -type d -printf '\''%Ts %Tc | %p/\n'\'' -o -printf '\''%Ts %Tc | %p\n'\'' \)'
				post_pipe_command='LC_ALL=C sort -rn | sed '\''s/^[^ ]\{1,\} //'\'' | '$post_pipe_command
			else
				find_command='find ././'$find_command
			fi
		fi
		result=$(
			[ -z "$dir" ] || cd -- "$dir" 2>/dev/null || exit 2
			if [ $COMP_RSEARCH -eq 0 ]; then
				find ./. -path '././*' -prune -type d
				echo ././
				if [ $dirsonly -eq 0 ]; then
					find ./. -path '././*' -prune ! -type d
				else
					find ./. -path '././*' -prune -type l
				fi
			else
				eval "$find_command"
			fi 2>/dev/null | xbash_awk '
			function print_path() {
				if(path == "") {
					if(!comp_rsearch) type++
					return
				}
				if(!xbash_startswith(tolower(path), ARGV[2])) return
				if(!comp_rsearch) print type xbash_ml2ol((path) (type ? "" : "/"))
				else if(comp_rsearch == 1) print xbash_ml2ol(path)
				else if(comp_rsearch == 2) print datetime_part xbash_ml2ol(path)
			}
			BEGIN {
				comp_rsearch = ARGV[1] + 0
				sub(/.*\//, "", ARGV[2])
				ARGV[2] = tolower(ARGV[2])
				type = 0
			}
			{
				if(comp_rsearch == 2) pos = index($0, " | ././")
				else if(substr($0, 1, 4) == "././") pos = 5
				else pos = 0
				if(pos) {
					if(NR != 1) print_path()
					if(comp_rsearch == 2) {
						datetime_part = substr($0, 1, pos + 2)
						pos += 7
					}
					path = substr($0, pos)
				} else path = path "\n" $0
			} END { if(NR) print_path() }' "$COMP_RSEARCH" "$COMP_VALUE" |
			eval "$post_pipe_command"
		) || return
		eval "COMP_VALUES=($(
			printf %s "$result" | xbash_awk 'BEGIN {
				comp_rsearch = ARGV[1]
				comp_value_dirname = ARGV[2]
				sub(/[^\57]+$/, "", comp_value_dirname)
			} {
				if(comp_rsearch == 2) sub(/^[^|]+\| /, "")
				print xbash_escape(comp_value_dirname xbash_ol2ml($0))
			}' "$COMP_RSEARCH" "$COMP_VALUE"
		))"
		if [ $COMP_RSEARCH -ne 0 ]; then
			COMP_NO_TRAILING_SPACE=1
		elif [ -d "${COMP_VALUES[-1]}" ]; then
			[ "${COMP_VALUES[-1]}" = "$COMP_VALUE" ] &&
			[ "${COMP_VALUES[-1]: -1}" != / ] &&
			COMP_VALUES[-1]+=/
			COMP_NO_TRAILING_SPACE=1
		fi
	else
		post_pipe_command='LC_ALL=C sort | '$post_pipe_command
		result=$(
			GLOBIGNORE=.:..; shopt -s nocaseglob nullglob
			eval "printf '//%s\\n' $(xbash_awk 'BEGIN {
				ORS = ""
				path_seg_count = split(ARGV[1], path_seg, "/")
				for(i = 1; i <= path_seg_count; i++) {
					if(i != 1) print "/"
					else if(path_seg[1] == "") continue
					if(path_seg[i] != "") print xbash_escape(path_seg[i])
					if(i != path_seg_count || path_seg[i] != "") print "*"
				}
			}' "$COMP_VALUE")" | xbash_awk '{
				if(substr($0, 1, 2) == "//") {
					if(NR != 1 && path != "") print xbash_ml2ol(path)
					path = substr($0, 3)
				} else path = path "\n" $0
			} END { if(NR && path != "") print xbash_ml2ol(path) }' |
			eval "$post_pipe_command"
		) || return
		eval "COMP_VALUES=($(
			printf %s "$result" | xbash_awk '{
				print xbash_escape(xbash_ol2ml($0))
			}'
		))"
		COMP_NO_TRAILING_SPACE=1
	fi
	return 0
}

xbash_compspecial_command() {
	if [[ "$COMP_VALUE" =~ ^\.?\.?/ ]]; then
		xbash_compspecial_fs
	else
		xbash_compspecial_compgen -c
	fi
}

# Usage: xbash_compspecial_eval [<shift_args>]
xbash_compspecial_eval() {
	local result pre_command
	[ -n "$1" ] && {
		set -- "${COMP_ARGV[@]:$1}"
		local COMP_ARGV
		COMP_ARGV=("$@")
		COMP_ARGC=$#
	}
	pre_command=${COMP_ARGV[*]}
	[ $COMP_ARGC -ne 0 ] && pre_command+=' '
	xbash_get_line_completion "$pre_command$COMP_VALUE" result || return 1
	result=${result:${#pre_command}}
	[ "$result" = "$COMP_VALUE" ] && return 1
	COMP_VALUES=("$result")
}

# Usage: xbash_compspecial_pid [multi|onlyown] ...
xbash_compspecial_pid() {
	local IFS result menu_args onlyown=0
	IFS=$XBASH_DEFAULT_IFS
	while [ $# -ne 0 ]; do
		case $1 in
		multi) menu_args=multi;;
		onlyown) onlyown=1;;
		esac
		shift
	done
	result=$({
		xbash_compgen_shell_child_pid "$COMP_VALUE"
		{
			if [ $onlyown -eq 0 ] || [ $EUID -eq 0 ]; then
				ps axf -o pid,user,args
			else
				ps xf -o pid,user,args
			fi 2>/dev/null || ps -Ao pid,user,args
		} | xbash_awk 'BEGIN {
			search_by_comm = ARGV[1] != "" && ARGV[1] !~ /^[1-9][0-9]*$/
			if(search_by_comm) ARGV[1] = tolower(ARGV[1])
			if((getline) <= 0) exit
		} {
			if(search_by_comm ? index(tolower($0), ARGV[1]) : xbash_startswith($1, ARGV[1]))
				print $0
		}' "$COMP_VALUE"
	} | xbash_menu $menu_args) || return
	COMP_VALUES=($(printf %s "$result" | LC_ALL=C awk -- '{ print $1 }'))
}

# Usage: xbash_compspecial_shell_child_pid [multi]
xbash_compspecial_shell_child_pid() {
	local result menu_args IFS=$'\n'
	[ "$1" = multi ] && menu_args=multi
	result=$(
		xbash_compgen_shell_child_pid "$COMP_VALUE" | xbash_menu $menu_args
	) || return
	COMP_VALUES=($(printf %s "$result" | LC_ALL=C awk '{ print $1 }'))
}

# Usage: xbash_compspecial_parse_help [<command>] [<eval_after>] [<detect_short_opts>] [<opt_var_name>]
# Performs `command` options completion using the xbash_compgen_parse_help()
# function. If the `detect_short_opts` argument is omitted or is equal to 1,
# then cases where short options are listed in a single argument will be
# automatically detected. If the `opt_var_name` argument is specified, then
# variable whose name is specified in it will contain the name of the selected
# parameter without the leading "-".
# Example: xbash_compspecial_parse_help grep '--help | grep -vF -e --help -e --version'
xbash_compspecial_parse_help() {
	local IFS=$'\n'
	[ $# -eq 0 ] && set -- "$COMP_COMMAND"
	[ $# -eq 1 ] && set -- "$1" --help
	[ -n "$1" ] && set -- "$1" '"$1" '"$2" "${@:3}"
	! awk -- 'BEGIN {
		exit !((ARGV[1] < 3 || ARGV[2]) && ARGV[3] ~ /^-[^-]/)
	}' $# "$3" "$COMP_VALUE"
	set -- "$1" "$2" "$?" "${@:4}"
	COMP_VALUES=("$(
		eval "$2" < /dev/null 2>&1 | xbash_compgen_parse_help "$COMP_VALUE" "$3" |
		xbash_menu multi
	)") || return
	[ $# -gt 3 ] && {
		set -- "$1" "$2" "$3" "$4" "$(printf %s "${COMP_VALUES[0]}" | LC_ALL=C awk 'END {
			if(!match($0, /^-([!#$%\57@_]|-?[A-Za-z0-9][A-Za-z0-9_-]*)/)) exit
			print substr($0, 2, RLENGTH - 1)
		}')"
		eval "$4=\$5"
	}
	COMP_VALUES=($(printf %s "${COMP_VALUES[0]}" | xbash_awk 'BEGIN {
		match_all_short_opts = ARGV[2] && ARGV[1] ~ /^-[^-]/
		if(match_all_short_opts) {
			ORS = ""
			print ARGV[1]
		}
	} {
		if(match_all_short_opts) {
			print substr($0, 2, 1)
			next
		}
		if(!match($0, /^-([!#$%\57@_]|-?[A-Za-z0-9][A-Za-z0-9_-]*)([[{(<]?=)?/)) next
		$0 = substr($0, RSTART, RLENGTH)
		sub(/[[{(<]?=$/, "=")
		print $0
	}' "$COMP_VALUE" "$3"))
	{ [ $3 -eq 1 ] || [[ "${COMP_VALUES[-1]}" = *= ]]; } &&
	COMP_NO_TRAILING_SPACE=1
	return 0
}

# Usage: xbash_compspecial_compgen [multi] [<compgen_arg>] ...
# Performs completion of values generated by the "compgen" bash builtin.
xbash_compspecial_compgen() {
	local menu_args IFS=$'\n'
	[ "$1" = multi ] && { menu_args=multi; shift; }
	COMP_VALUES=($(
		compgen "$@" | xbash_istartswith "$COMP_VALUE" |
		LC_ALL=C sort -u | xbash_menu $menu_args
	))
}

# Usage: xbash_compspecial_bash_completion <command>
xbash_compspecial_bash_completion() {
	local result IFS=$'\n'
	[ $# -eq 0 ] && set -- "$COMP_COMMAND"
	result=$(
		IFS=$XBASH_DEFAULT_IFS
		xbash_compgen_bash_completion "$1" "${COMP_ARGV[@]:1}" "$COMP_VALUE_BEFORE$COMP_VALUE" |
		xbash_menu multi
	) || return
	COMP_VALUES=($(
		printf %s "$result" | xbash_awk '{
			if(xbash_startswith($0, ARGV[1])) print $0
			else {
				i = length($0)
				if(i > length(ARGV[1])) i = length(ARGV[1])
				while(i) {
					if(substr(ARGV[1], length(ARGV[1]) - i + 1, i) == substr($0, 1, i)) break
					i--
				}
				if(i) print substr(ARGV[1], 1, length(ARGV[1]) - i) $0
				else print ARGV[1] $0
			}
		}' "$COMP_VALUE_BEFORE$COMP_VALUE"
	))
	[[ "${COMP_VALUES[-1]}" != *[=,] ]] || COMP_NO_TRAILING_SPACE=1
}

# Usage: xbash_compspecial_common [<parse_help_command>] [<parse_help_eval_after>]
# Performs common completion using the xbash_compspecial_parse_help() and
# xbash_compspecial_bash_completion() functions. The function accepts the same
# arguments as the xbash_compspecial_parse_help() function.
xbash_compspecial_common() {
	COMP_VALUE=$COMP_VALUE_BEFORE$COMP_VALUE
	COMP_VALUE_BEFORE=
	[ "${COMP_VALUE::1}" = - ] && {
		xbash_move_substr '-([^=-]|-[^=])[^=]*=' COMP_VALUE COMP_VALUE_BEFORE && return 2
		xbash_compspecial_parse_help "$@"
		case $? in
		0|1) return;;
		esac
	}
	xbash_compspecial_bash_completion
}


## Context completion functions

xbash_compcontext_expand() {
	COMP_LINE_REPLACE=$(
		# GLOBIGNORE=.:..
		# shopt -u dotglob
		eval 'xbash_escape 0 0 "$COMP_STRING_ESCAPING" -- '"$COMP_UNEXPANDED"
	)
}

xbash_compcontext_filepath() {
	xbash_compspecial_fs || return
	xbash_compspecial_apply_comp_values
}

xbash_compcontext_varname() {
	local result
	result=$(compgen -v | xbash_istartswith "$COMP_VALUE" | xbash_menu) || return
	COMP_LINE_REPLACE=$result
}

xbash_compcontext_before_command() {
	local pos matched
	{
		[[ "$COMP_VALUE" =~ ^\.?\.?/ ]] ||
		[ "$COMP_LINE_REPLACE" = '~' ] ||
		[[ "$COMP_LINE_REPLACE" =~ ^~[A-Za-z%,.:@_][A-Za-z0-9%+,.:@_-]*$ ]]
	} && {
		xbash_compspecial_fs || return
		xbash_compspecial_apply_comp_values
		return
	}
	[[ "$COMP_LINE_REPLACE" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && {
		pos=${#BASH_REMATCH[0]}
		matched=${COMP_VALUE::pos-1}
		COMP_VALUE_BEFORE+=${COMP_VALUE::pos}
		COMP_VALUE=${COMP_VALUE:pos}
		{
			eval "xbash_istartswith \"\$COMP_VALUE\" \"\$$matched\" > /dev/null" &&
			eval "COMP_VALUES=(\"\$$matched\")" &&
			[ -n "${COMP_VALUES[0]}" ] &&
			COMP_NO_TRAILING_SPACE=1
		} || xbash_compspecial_fs || return
		xbash_compspecial_apply_comp_values
		return
	}
	COMP_VALUES=("$(
		xbash_compgen_before_command |
		xbash_istartswith "$COMP_VALUE" | xbash_menu
	)") ||
	case $? in
	2)
		COMP_VALUES=("$(
			xbash_compgen_before_command |
			xbash_awk 'BEGIN {
				ARGV[1] = tolower(ARGV[1])
				min_dist = has_results = 0
			} {
				dist = xbash_levenshtein(tolower($0), ARGV[1], 3, 2, 1)
				if(dist < 5) {
					has_results = 1
					print dist " " $0
				}
				if(!has_results && (!min_dist || dist < min_dist)) {
					min_dist = dist
					min_dist_result = $0
				}
			} END {
				if(!has_results && min_dist) print min_dist " " min_dist_result
			}' "$COMP_VALUE" |
			LC_ALL=C sort -n | sed 's/^[^ ]* //' | xbash_menu
		)") || return
		;;
	*) return;;
	esac
	if [ "${COMP_VALUES[0]: -1}" = $'\e' ]; then
		COMP_LINE_REPLACE=$(xbash_awk 'BEGIN {
			if(!sub(/[\t ]+#.*/, "", ARGV[1]))
				ARGV[1] = substr(ARGV[1], 1, length(ARGV[1]) - 1)
			print xbash_ol2ml(ARGV[1])
		}' "${COMP_VALUES[0]}")
		unset -v 'COMP_VALUES[0]'
	else
		[[ "${COMP_VALUES[0]}" != *= ]] || COMP_NO_TRAILING_SPACE=1
		COMP_LINE_REPLACE=$(xbash_escape 0 1 "$COMP_STRING_ESCAPING" -- "${COMP_VALUES[0]}")
	fi
	[ $COMP_STRING_ESCAPING -ne 0 ] || [ $COMP_NO_TRAILING_SPACE -ne 0 ] || COMP_LINE_REPLACE+=' '
}

xbash_compcontext_command() {
	local retval COMP_COMMAND
	COMP_COMMAND=${COMP_ARGV[0]##*/}
	if [ "$COMP_LINE_REPLACE" = '~' ] || [[ "$COMP_LINE_REPLACE" =~ ^~[A-Za-z%,.:@_][A-Za-z0-9%+,.:@_-]*$ ]]; then
		retval=2
	elif [ -z "$COMP_COMMAND" ] || [ "$COMP_COMMAND" = .. ] || [[ "$COMP_COMMAND" = *=* ]]; then
		retval=1
	else
		case $COMP_COMMAND in
		.) COMP_COMMAND=source;;
		'[') COMP_COMMAND=test;;
		esac
		declare -F xbash_comp_"$COMP_COMMAND" > /dev/null ||
		xbash_completion_loader "$COMP_COMMAND"
		if declare -F xbash_comp_"$COMP_COMMAND" > /dev/null; then
			if [ $COMP_ARGC -gt 1 ]; then
				set -- "$COMP_VALUE" "${COMP_ARGV[COMP_ARGC - 1]}"
			else
				set -- "$COMP_VALUE"
			fi
			xbash_comp_"$COMP_COMMAND" "$@"
		else
			xbash_compspecial_bash_completion
		fi
		retval=$?
	fi
	{
		[ $retval -eq 0 ] || {
			[ $retval -eq 2 ] && xbash_compspecial_fs multi
		}
	} && [ ${#COMP_VALUES[@]} -ne 0 ] && xbash_compspecial_apply_comp_values
}


[ -z "$USER" ] && USER=$(id -nu)

# Loading bash completion if it was not loaded
declare -F _completion_loader > /dev/null || {
	[ -f /usr/share/bash-completion/bash_completion ] &&
	. /usr/share/bash-completion/bash_completion 2>/dev/null
} || {
	[ -f /etc/bash_completion ] &&
	. /etc/bash_completion 2>/dev/null
}

# HACK: Attempting to rollback conflicting changes made by the
# /etc/bash_completion.d/fzf script, which comes with fzf package on some
# distros. If it hasn't been loaded, this code doesn't do anything.
eval "$(
	complete -p | awk 'BEGIN {
		for(i = 1; i < ARGC; i++) longopt_comp[ARGV[i]] = ""
		ARGC = 1
		has_fzf_definitions = 0
	} {
		for(i = NF - 2; i > 1; i--) if($i == "-F" && substr($(i + 1), 1, 5) == "_fzf_") {
			gsub(/\47/, "\47\134\47\47", $NF)
			if($NF in longopt_comp) print "complete -F _longopt \47" $NF "\47"
			else print "_completion_loader \47" $NF "\47"
			has_fzf_definitions = 1
			next
		}
	} END { exit !has_fzf_definitions }' \
		a2ps awk base64 bash bc bison cat chroot colordiff cp \
		csplit cut date df diff dir du enscript env expand fmt fold gperf \
		grep grub head irb ld ldd less ln ls m4 md5sum mkdir mkfifo mknod \
		mv netstat nl nm objcopy objdump od paste pr ptx readelf rm rmdir \
		sed seq sha{,1,224,256,384,512}sum shar sort split strip sum tac tail tee \
		texindex touch tr uname unexpand uniq units vdir wc who
	if [ $? -eq 0 ]; then
		compgen -A function | awk 'BEGIN { ORS = " "; print "unset -f" } /^__?fzf_/ { print $0 }'; echo
		compgen -v | awk 'BEGIN { ORS = " "; print "unset -v" } /^__?fzf_/ { print $0 }'; echo
		echo true
	else
		echo false
	fi
)" &&
xbash_err 'fzf completion file was previously loaded, but the definitions it created has been removed, because they conflicts with xbash. To prevent loading the /etc/bash_completion.d/fzf file, create a /etc/bash_completion.d/_completions_blacklist file with the following contents: _blacklist_glob='\''@(fzf)'\'


[ -e /etc/xbashrc ] && . /etc/xbashrc

# You can blacklist an includes by specifying it in the
# XBASH_INCLUDES_BLACKLIST_GLOB variable. See description of the
# xbash_includedirs() function for details.
xbash_includedirs \
	/usr/share/xbash{,/plugins} \
	/usr/local/share/xbash{,/plugins} \
	/etc/xbash{,/plugins} \
	~/.xbash{,/plugins}
