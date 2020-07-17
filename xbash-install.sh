#!/usr/bin/env sh
#
# xbash installer
#
# Copyright (c) 2020 10geek
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

term_input() {
	unset -v ui_input
	while :; do
		ui_input=$(
			export ui_input
			dd bs=1 count=1 2>/dev/null | LC_ALL=C awk -- 'BEGIN {
				ARGC = 1
				if((getline) <= 0) {
					if(ARGV[1] + 0 && ENVIRON["ui_input"] == "") exit 0
					exit 1
				}
				gsub(/\0/, "")
				is_utf8 = (ENVIRON["ui_input"] == "" && $0 ~ /^[\300-\367]$/) || (ENVIRON["ui_input"] ~ /^([\300-\336\337]|[\340-\357][\200-\277]?|[\360-\367][\200-\277]?[\200-\277]?)$/ && $0 ~ /^[\200-\277]$/)
				if($0 == "") input = 10
				else if($0 ~ /^[\41-\176]$/ || is_utf8) input = $0
				else {
					for(i = 1; i < 33; i++) if($0 == sprintf("%c", i)) {
						if(i < 10) input = "0" i
						else input = i
						break
					}
					if(i == 33) for(i = 127; i < 256; i++) if($0 == sprintf("%c", i)) {
						input = i
						break
					}
				}
				if(ENVIRON["ui_input"] != "" && !is_utf8) ENVIRON["ui_input"] = ENVIRON["ui_input"] " "
				printf("%s", ENVIRON["ui_input"])
				print input
				if(ENVIRON["ui_input"] input ~ /^([\300-\367]|[\340-\367][\200-\277]|[\360-\367][\200-\277][\200-\277]|27( \[( \[| [0-9]( [0-9]( ;( [0-9])?)?| ;( [0-9])?)?)?| O( [0-9])?)?)$/) exit 1
			}' "$1"
		) && break
	done
}
ui_mode() {
	case $1 in
	on)
		[ -n "$ui_mode__stty_old_settings" ] && return 0
		{
			ui_mode__stty_old_settings=$(stty -g < /dev/tty) &&
			[ -n "$ui_mode__stty_old_settings" ] &&
			stty -icanon -echo < /dev/tty
		} || return 1
		printf '\33[?1049h\33[?1h\33=\33[?25l'
		;;
	off)
		[ -z "$ui_mode__stty_old_settings" ] && return 0
		stty "$ui_mode__stty_old_settings" < /dev/tty || return 1
		unset -v ui_mode__stty_old_settings
		printf '\33[?25h\33[0m\33[?1l\33>\n\33[?1049l'
		;;
	*) return 1;;
	esac
}
unset -v ui_mode__stty_old_settings
ui_callback() { :; }
ui() {
	ui_mode on || return 1
	unset -v ui_choice ui_event ui_input ui_menu_height_old ui_output ui_search ui_value_l ui_value_r ui_var_name
	ui_init=1
	ui_title=$1
	ui_description=$2
	ui_menu=$3
	ui_menu_cursor_pos=$4
	while :; do
		unset -v ui_action
		eval "$(stty -a < /dev/tty | awk 'BEGIN { w = h = 0 } {
			gsub(/[;=]/, " ")
			for(i = 1; i < NF; i++) {
				if($i == "rows") h = int($(++i) + 0)
				else if($i == "columns" || $i == "cols") w = int($(++i) + 0)
				if(w > 0 && h > 0) exit
			}
		} END {
			if(w < 1) w = 80
			if(h < 1) h = 24
			print "ui_stty_width=" w "; ui_stty_height=" h
		}')"
		if [ "$ui_event" = edit ] || [ "$ui_event" = search_edit ]; then
			eval "$(
			export ui_event ui_input ui_value_l ui_value_r
			LC_ALL=C awk -- '
			function shell_escape(_in) {
				gsub(/\0/, "", _in)
				gsub(/\47/, "\47\134\47\47", _in)
				return "\47" _in "\47"
			}
			BEGIN {
				non_word_chars = "][ \t\r\n\v\f/\\\\()\"\47:,.;<>~!@#$%^&*|+={}`?-"
				input = ENVIRON["ui_input"]
				value_l = ENVIRON["ui_value_l"]
				value_r = ENVIRON["ui_value_r"]
				l_changed = 0; r_changed = 0
				if(input ~ /^(32|[\41-\176]|[\300-\336\337][\200-\277]|[\340-\357][\200-\277][\200-\277]|[\360-\367][\200-\277][\200-\277][\200-\277])$/) {
					l_changed = 1
					if(input == "32") input = " "
					value_l = value_l input
				} else if(input == "27 O A" || input == "27 O B") {
					if(ENVIRON["ui_event"] == "search_edit")
						print "ui_value_l=$ui_search\nunset -v ui_value_r"
				} else if(input == "27 O D" || input == "02") {
					if(value_l == "") exit
					l_changed = r_changed = 1
					if(match(value_l, /[^\1-\177\300-\367]*$/) < 3) {
						value_r = value_l value_r
						value_l = ""
					} else {
						value_r = substr(value_l, RSTART - 1, RLENGTH + 1) value_r
						value_l = substr(value_l, 1, RSTART - 2)
					}
				} else if(input == "27 O C" || input == "06") {
					if(value_r == "") exit
					l_changed = r_changed = 1
					if(match(value_r, /^.[^\1-\177\300-\367]*[\1-\177\300-\367]/)) {
						value_l = value_l substr(value_r, 1, RLENGTH - 1)
						value_r = substr(value_r, RLENGTH)
					} else {
						value_l = value_l value_r
						value_r = ""
					}
				} else if(input == "27 [ 1 ; 5 D") {
					if(value_l == "") exit
					l_changed = r_changed = 1
					if(match(value_l, "[^" non_word_chars "]*[" non_word_chars "]*$") < 2) {
						value_r = value_l value_r
						value_l = ""
					} else {
						value_r = substr(value_l, RSTART, RLENGTH) value_r
						value_l = substr(value_l, 1, RSTART - 1)
					}
				} else if(input == "27 [ 1 ; 5 C") {
					if(value_r == "") exit
					l_changed = r_changed = 1
					if(match(value_r, "^[" non_word_chars "]*[^" non_word_chars "]+[" non_word_chars "]")) {
						value_l = value_l substr(value_r, 1, RLENGTH - 1)
						value_r = substr(value_r, RLENGTH)
					} else {
						value_l = value_l value_r
						value_r = ""
					}
				} else if(input == "27 O H" || input == "27 [ 1 ~" || input == "01") {
					if(value_l == "") exit
					l_changed = r_changed = 1
					value_r = value_l value_r
					value_l = ""
				} else if(input == "27 O F" || input == "27 [ 4 ~" || input == "05") {
					if(value_r == "") exit
					l_changed = r_changed = 1
					value_l = value_l value_r
					value_r = ""
				} else if(input == "127" || input == "08") {
					if(sub(/.[^\1-\177\300-\367]*$/, "", value_l)) l_changed = 1
				} else if(input == "27 [ 3 ~" || input == "04") {
					if(sub(/^.[^\1-\177\300-\367]*/, "", value_r)) r_changed = 1
				} else if(input == "23") {
					l_changed = 1
					sub("[^" non_word_chars "]*[" non_word_chars "]*$", "", value_l)
				} else if(input == "27 [ 3 ; 5 ~") {
					r_changed = 1
					sub("^[" non_word_chars "]*[^" non_word_chars "]*", "", value_r)
				} else if(input == "21") {
					l_changed = 1
					value_l = ""
				} else if(input == "11") {
					r_changed = 1
					value_r = ""
				} else if(input == "10") {
					if(ENVIRON["ui_event"] == "search_edit") print "ui_event=search_edit_complete"
					else print "ui_event=edit_complete"
				} else if(input == "31" || input == "27 27")
					print "printf \47\\33[?25l\47\nunset -v ui_event"
				if(l_changed) print "ui_value_l=" shell_escape(value_l)
				if(r_changed) print "ui_value_r=" shell_escape(value_r)
			}')"
		else
			case $ui_input in
			'27 O H'|'27 [ 1 ~') ui_action=nav_home;;
			'27 O F'|'27 [ 4 ~') ui_action=nav_end;;
			'10'|'32') ui_action=select;;
			'N'|'27 O 2 R'|'27 [ 2 8 ~') ui_action=search_prev;;
			'n'|'27 O R'|'27 [ [ C') ui_action=search_next;;
			'/'|'06') ui_action=search_edit;;
			'q'|'127'|'27 27') ui_event=exit;;
			esac
		fi
		case $ui_input in
		'27 O A') ui_action=nav_up;;
		'27 O B') ui_action=nav_down;;
		'27 [ 5 ~') ui_action=nav_page_up;;
		'27 [ 6 ~') ui_action=nav_page_down;;
		'27 [ Z'|'27 [ 1 ; 5 A') ui_action=nav_prev_selectable;;
		'09'|'27 [ 1 ; 5 B') ui_action=nav_next_selectable;;
		esac
		[ -n "$ui_action" ] && [ "$ui_event" = edit ] && ui_event=edit_complete
		ui_callback "$@"
		{ [ "$ui_event" = select ] || [ "$ui_event" = exit ]; } && break
		unset -v ui_choice ui_input
		if [ "$ui_event" = edit ] || [ "$ui_event" = search_edit ]; then
			unset -v ui_action
		else
			case $ui_event in
			edit_complete)
				printf '\33[?25l'
				expr "$ui_var_name" : '[A-Za-z_][A-Za-z0-9_]*$' > /dev/null &&
					eval "$ui_var_name=\$ui_value_l\$ui_value_r"
			;;
			search_edit_complete)
				printf '\33[?25l'
				ui_search=$ui_value_l$ui_value_r
				ui_action=search_next
			;;
			esac
			unset -v ui_event ui_var_name
		fi
		ui_output=$(
		export ui_action ui_description ui_event ui_menu_cursor_pos ui_menu_height_old ui_search ui_title ui_value_l ui_value_r
		eval "$(printf %s "$ui_menu" | awk '{
			if(sub(/^[ \t]*[cimpr]/, "") && match($0, /^[A-Za-z_][A-Za-z0-9_]*/))
				print "export " substr($0, RSTART, RLENGTH)
		}')"
		printf %s "$ui_menu" | LC_ALL=C awk -- '
		function mblength(__in) {
			gsub(/[^\1-\177\300-\367]/, "", __in)
			return length(__in)
		}
		function mbcharpos(__in, __i) {
			__i += 0; __l = length(__in)
			if(__i < 1 || __i > __l) {
				RSTART = 0; RLENGTH = -1
				return 0
			}
			RLENGTH = 0
			for(RSTART = 1; RSTART <= __l; RSTART++) {
				__ord = ord[substr(__in, RSTART, 1)]
				if((__ord < 128 || __ord > 191) && --__i == 0) {
					if(__ord < 128) RLENGTH = 1
					else if(__ord < 224) RLENGTH = 2
					else if(__ord < 240) RLENGTH = 3
					else if(__ord < 248) RLENGTH = 4
					else RLENGTH = 1
					break
				}
			}
			if(!RLENGTH) {
				RSTART = 0; RLENGTH = -1
			} else if(RSTART + RLENGTH - 1 > __l) RLENGTH = 1
			else if(RLENGTH > 1) {
				for(__i = RSTART + 1; __i < RSTART + RLENGTH; __i++) {
					__ord = ord[substr(__in, __i, 1)]
					if(__ord < 128 || __ord > 191) {
						RLENGTH = 1
						break
					}
				}
			}
			return RSTART
		}
		function wordwrap(_in, _width, _fill_space, _max_lines, _add_ellipsis) {
			_out = ""
			_in_lines_count = split(_in, _tmp, "\n")
			_lines_count = 0
			for(_i = 1; _i <= _in_lines_count; _i++) {
				if(_i != 1) _out = _out "\n"
				while(mbcharpos(_tmp[_i], _width + 1)) {
					_lines_count++
					if(_max_lines > 0 && _lines_count == _max_lines) _max_lines = -1
					_line_length = RSTART - 1
					_line = substr(_tmp[_i], 1, _line_length + RLENGTH)
					if(_max_lines == -1 && _add_ellipsis) {
						mbcharpos(_line, _width - 1)
						if(RSTART) match(substr(_line, 1, RSTART - 1), / +[^ ]*$/)
					} else match(_line, / [^ ]*$/)
					if(RSTART) {
						_line = substr(_line, 1, RSTART - 1)
						if(_max_lines == -1 && _add_ellipsis) _line = _line "..."
						else sub(/ *$/, "", _line)
						if(_fill_space) {
							_line_length = mblength(_line)
							_line = _line sprintf("%" _width - _line_length "s", "")
						}
						if(_max_lines != -1) {
							_tmp[_i] = substr(_tmp[_i], RSTART + 1)
							sub(/^ */, "", _tmp[_i])
						}
					} else {
						if(_max_lines == -1 && _add_ellipsis) {
							mbcharpos(_line, _width - 3)
							if(RSTART) _line = substr(_line, 1, RSTART + RLENGTH - 1) "..."
							else _line = "..."
						} else _line = substr(_tmp[_i], 1, _line_length)
						if(_max_lines != -1) _tmp[_i] = substr(_tmp[_i], _line_length + 1)
					}
					_out = _out _line
					if(_max_lines == -1) break
					if(_tmp[_i] != "") _out = _out "\n"
				}
				if(_max_lines != -1) {
					_lines_count++
					if(_max_lines > 0 && _lines_count == _max_lines) {
						_max_lines = -1
						if(_add_ellipsis && _i != _in_lines_count) {
							_line_length = mblength(_tmp[_i])
							if(_width - _line_length > 2) _tmp[_i] = _tmp[_i] "..."
							else {
								mbcharpos(_tmp[_i], _width - 2)
								if(RSTART && match(substr(_tmp[_i], 1, RSTART + RLENGTH - 1), / +[^ ]*$/)) _tmp[_i] = substr(_tmp[_i], 1, RSTART - 1) "..."
								else {
									mbcharpos(_tmp[_i], _width - 3)
									if(RSTART) _tmp[_i] = substr(_tmp[_i], 1, RSTART + RLENGTH - 1) "..."
									else _tmp[_i] = "..."
								}
							}
						}
					}
					if(_fill_space) {
						_line_length = mblength(_tmp[_i])
						_tmp[_i] = _tmp[_i] sprintf("%" _width - _line_length "s", "")
					}
					_out = _out _tmp[_i]
				}
				if(_max_lines == -1) break
			}
			return _out
		}
		function filter_printable(_in) {
			_out = ""
			gsub(/\t/, "    ", _in)
			gsub(/\0/, "", _in)
			while(_in != "") {
				if(!match(_in, /([\n\40-\176]|[\303-\310\312\313\320\321\332][\200-\277]|\302[\240-\277]|\311[\200\201\220-\277]|\315[\264\265\272\276]|\316[\204-\212\214\216-\241\243-\277]|\317[\200-\216\220-\277]|\322[\200-\202\212-\277]|\323[\200-\216\220-\271]|\324[\200-\217\261-\277]|\325[\200-\226]|\325[\231-\237\241-\277]|\326[\200-\207\211-\212\276]|\327[\200\203\206\220-\252\260-\264]|\330[\213-\217\233\236\237\241-\272]|\331[\200-\212\240-\257\261-\277]|\333[\200-\225\245\246\251\256-\277]|\334[\200-\215\220\222-\257]|\335[\215-\255]|\336[\200-\245\261]|\340(\244[\203-\271\275-\277]|\245[\200\211-\214\220\230-\241\244-\260\275]|\246[\202\203\205-\214\217\220\223-\250\252-\260\262\266-\271\275-\277]|\247[\200\207\210\213\214\216\227\234\235\237-\241\246-\272]|\250[\203\205-\212\217\220\223-\250\252-\260\262\263\265\266\270\271\276\277]|\251[\200\231-\234\236\246-\257\262-\264]|\252[\203\205-\215\217-\221\223-\250\252-\260\262\263\265-\271\275-\277]|\253[\200\211\213\214\220\240\241\246-\257\261]|\254[\202\203\205-\214\217\220\223-\250\252-\260\262\263\265-\271\275\276]|\255[\200\207\210\213\214\227\234\235\237-\241\246-\261]|\256[\203\205-\212\216-\220\222-\225\231\232\234\236\237\243\244\250-\252\256-\271\276\277]|\257[\201\202\206-\210\212-\214\227\246-\272]|\260[\201-\203\205-\214\216-\220\222-\250\252-\263\265-\271]|\261[\201-\204\240\241\246-\257]|\262[\202\203\205-\214\216-\220\222-\250\252-\263\265-\271\275\276]|\263[\200-\204\207\210\212\213\225\226\236\240\241\246-\257]|\264[\202\203\205-\214\216-\220\222-\250\252-\271\276\277]|\265[\200\206-\210\212-\214\227\240-\241\246-\257]|\266[\202\203\205-\226\232-\261\263-\273\275]|\267[\200-\206\217-\221\230-\237\262-\264]|\270[\201-\260\262\263\277]|\271[\200-\206\217-\233]|\272[\201\202\204\207\210\212\215\224-\227\231-\237\241-\243\245\247\252\253\255-\260\262\263\275]|\273[\200-\204\206\220-\231\234\235]|\274[\200-\227\232-\264\266\270\272-\277]|\275[\200-\207\211-\252\277]|\276[\205\210-\213\276\277]|\277[\200-\205\207-\214\217-\221])|\341(\200[\200-\241\243-\247\251\252\254\261\270]|\201[\200-\227]|\202\240|\203[\205\220-\274]|\210\200|\211[\210\212-\215\220-\226\230\232-\235\240-\277]|\212[\200-\210\212-\215\220-\260\262-\265\270-\276]|\213[\200\202-\205\210-\226\230-\277]|\214[\200-\220\222-\225\230-\277]|\215[\200-\232\240-\274]|\216[\200-\231\240-\277]|\217[\200-\264]|\220\201|\231\266|\220\201|\231\266|\232[\200-\234\240-\277]|\233[\200-\260]|\234[\200-\214\216-\221\240-\261\265\266]|\235[\200-\221\240-\254\256-\260]|\236[\200-\263\266\276\277]|\237[\200-\205\207\210\224-\234\240-\251\260-\271]|\240[\200-\212\216\220-\231\240-\277]|\241[\200-\267]|\242[\200-\250]|\244[\200-\234\243-\246\251-\253\260\261\263-\270]|\245[\200\204-\255\260-\264]|\246[\200-\251\260-\277]|\247[\200-\211\220-\231\236-\277]|\250[\200-\226\231-\233\236\237]|[\264-\266\270\271][\200-\277]|\272[\200-\233\240-\277]|\273[\200-\271]|\274[\200-\225\230-\235\240-\277]|\275[\200-\205\210-\215\220-\227\231\233\235\237-\275]|\276[\200-\264\266-\277]|\277[\200-\204\206-\223\226-\233\235-\257\262-\264\266-\276])|\342([\204\207-\213\215\216\222-\231\240-\253\262][\200-\277]|\200[\200-\212\220-\251\257-\277]|\201[\200-\237\260\261\264-\277]|\202[\200-\216\220-\224\240-\265]|\205[\200-\214\223-\277]|\206[\200-\203\220-\277]|\214[\200-\250\253-\277]|\217[\200-\233]|\220[\200-\246]|\221[\200-\212\240-\277]|\232[\200-\234\240-\261]|\234[\201-\204\206-\211\214-\247\251-\277]|\235[\200-\213\215\217-\222\226\230-\236\241-\277]|\236[\200-\224\230-\257\261-\276]|\237[\200-\206\220-\253\260-\277]|\254[\200-\223]|\260[\200-\256\260-\277]|\261[\200-\236]|\263[\200-\252\271-\277]|\264[\200-\245\260-\277]|\265[\200-\245\257]|\266[\200-\226\240-\246\250-\256\260-\266\270-\276]|\267[\200-\206\210-\216\220-\226\230-\236]|\270[\200-\227\234-\235])|\352(\234[\200-\226]|\240[\200-\205\207-\212\214-\244\247-\253])|\356\200\200|\357(\243\277|\254[\200-\206\223-\227\235\237-\266\270-\274\276]|\255[\200\201\203\204\206-\277]|\256[\200-\261]|\257[\223-\277]|[\260-\264][\200-\277]|\265[\220-\277]|\266[\200-\217\222-\277]|\267[\200-\207\260-\275]|\271[\260-\264\266]|\273[\200-\274]|\275[\241-\277]|\276[\200-\276]|\277[\202-\207\212-\217\222-\227\232-\234\250-\256\274\275]))+/))
					_replaced_chars_count = mblength(_in)
				else if(RSTART > 1)
					_replaced_chars_count = mblength(substr(_in, 1, RSTART - 1))
				if(RSTART != 1) {
					for(_i = 0; _i < _replaced_chars_count; _i++)
						_out = _out "\357\277\275"
					if(!RSTART) break
				}
				_out = _out substr(_in, RSTART, RLENGTH)
				_in = substr(_in, RSTART + RLENGTH)
			}
			return _out
		}
		function shell_escape(_in) {
			gsub(/\0/, "", _in)
			gsub(/\n/, "\n.", _in)
			gsub(/\47/, "\47\134\47\47", _in)
			return "\47" _in "\47"
		}
		function is_checked(_menu_index) {
			if(menu_items_type[_menu_index] == "m") {
				if(!(menu_items_vars[_menu_index] in multiselect_values)) {
					multiselect_values[menu_items_vars[_menu_index]] = ""
					_tmp_count = split(ENVIRON[menu_items_vars[_menu_index]], _tmp, "\n")
					for(_i = 1; _i <= _tmp_count; _i++)
						multiselect_values[menu_items_vars[_menu_index] ":" _tmp[_i]] = ""
				}
				if(_menu_index in menu_items_values)
					return menu_items_vars[_menu_index] ":" menu_items_values[_menu_index] in multiselect_values
				return menu_items_vars[_menu_index] ":" menu_items[_menu_index] in multiselect_values
			} else if(menu_items_type[_menu_index] == "c")
				return (ENVIRON[menu_items_vars[_menu_index]] ~ /^[1-9][0-9]*$/) == (!(_menu_index in menu_items_values) || menu_items_values[_menu_index] ~ /^[1-9][0-9]*$/)
			else if(menu_items_type[_menu_index] == "r") {
				if(_menu_index in menu_items_values)
					return ENVIRON[menu_items_vars[_menu_index]] == menu_items_values[_menu_index]
				return ENVIRON[menu_items_vars[_menu_index]] == menu_items[_menu_index]
			} else return -1
		}
		BEGIN {
			ARGC = 1
			for(i = 0; i < 256; i++) ord[sprintf("%c", i)] = i
			term_w = ARGV[1] + 0
			term_h = ARGV[2] + 0
			action = ENVIRON["ui_action"]
			event = ENVIRON["ui_event"]
			menu_height_old = ENVIRON["ui_menu_height_old"] + 0
			menu_cursor_pos = ENVIRON["ui_menu_cursor_pos"] + 0
			print_at_end = ""
			menu_items_count = 0
		} {
			menu_items_count++
			sub(/^[ \t]+/, "")
			if(match($0, /^[cimpr][A-Za-z_][A-Za-z0-9_]*/)) {
				menu_items_type[menu_items_count] = substr($0, 1, 1)
				menu_items_vars[menu_items_count] = substr($0, RSTART + 1, RLENGTH - 1)
				menu_items[menu_items_count] = substr($0, RSTART + RLENGTH + 1)
			} else if(match($0, /^[bqht]/)) {
				menu_items_type[menu_items_count] = substr($0, 1, 1)
				menu_items[menu_items_count] = substr($0, 2)
			} else {
				menu_items_count--
				if(!menu_items_count) next
				if(sub(/^v/, "")) {
					if(menu_items_type[menu_items_count] != "m" && menu_items_count in menu_items_values)
						menu_items_values[menu_items_count] = menu_items_values[menu_items_count] "\n" $0
					else
						menu_items_values[menu_items_count] = $0
				} else if(sub(/^d/, "")) {
					if(menu_items_count in menu_items_desc_raw)
						menu_items_desc_raw[menu_items_count] = menu_items_desc_raw[menu_items_count] "\n" $0
					else
						menu_items_desc_raw[menu_items_count] = $0
				} else if(sub(/^s/, "")) {
					if(ENVIRON["ui_menu_cursor_pos"] == "") menu_cursor_pos = menu_items_count
				}
			}
		} END {
			if(!menu_items_count) {
				menu_items_count = split(wordwrap(filter_printable(ENVIRON["ui_description"]), term_w - 2, 0, 0, 0), _tmp, "\n")
				for(i = 1; i <= menu_items_count; i++) {
					menu_items[i] = _tmp[i]
					menu_items_type[i] = "t"
				}
				default_desc = ENVIRON["ui_description"] = ""
				desc_height = default_desc_height = 0
			} else {
				default_desc = wordwrap(filter_printable(ENVIRON["ui_description"]), term_w, 1, 0, 0)
				desc_height = default_desc_height = _lines_count
			}
			if(action == "nav_up") menu_cursor_pos--
			else if(action == "nav_down") menu_cursor_pos++
			else if(action == "nav_page_up") menu_cursor_pos -= int(menu_height_old / 2)
			else if(action == "nav_page_down") menu_cursor_pos += int(menu_height_old / 2)
			else if(action == "nav_home") menu_cursor_pos = 1
			else if(action == "nav_end") menu_cursor_pos = menu_items_count
			else if(action == "nav_prev_selectable") {
				for(i = menu_cursor_pos - 1; i != menu_cursor_pos; i--) {
					if(i < 1) {
						if(menu_cursor_pos == menu_items_count) break
						i = menu_items_count
					}
					if(menu_items_type[i] != "h" && menu_items_type[i] != "t") {
						menu_cursor_pos = i
						break
					}
				}
			} else if(action == "nav_next_selectable") {
				for(i = menu_cursor_pos + 1; i != menu_cursor_pos; i++) {
					if(i > menu_items_count) {
						if(menu_cursor_pos == 1) break
						i = 1
					}
					if(menu_items_type[i] != "h" && menu_items_type[i] != "t") {
						menu_cursor_pos = i
						break
					}
				}
			} else if(action == "select" && menu_cursor_pos in menu_items) {
				if(menu_items_type[menu_cursor_pos] == "i" || menu_items_type[menu_cursor_pos] == "p") {
					print ".ui_event=edit\n.ui_var_name=" menu_items_vars[menu_cursor_pos] "\n.ui_value_l=$" menu_items_vars[menu_cursor_pos] "\n.ui_value_r=\47\47\n.printf \47\\33[?25h\47\n.continue"
					exit
				} else if(menu_items_type[menu_cursor_pos] == "m") {
					if(menu_cursor_pos in menu_items_values) menu_item_value = menu_items_values[menu_cursor_pos]
					else menu_item_value = menu_items[menu_cursor_pos]
					if(is_checked(menu_cursor_pos)) {
						delete multiselect_values[menu_items_vars[menu_cursor_pos] ":" menu_item_value]
						is_first = 1
						for(i = 1; i <= _tmp_count; i++) {
							if(_tmp[i] == menu_item_value) continue
							if(is_first) {
								is_first = 0
								if(_tmp[i] == "") menu_item_var_value = "\n"
								else menu_item_var_value = _tmp[i]
							} else if(_tmp[i] == "") {
								if(menu_item_var_value !~ /^\n/)
									menu_item_var_value = "\n" menu_item_var_value
							} else
								menu_item_var_value = menu_item_var_value "\n" _tmp[i]
						}
					} else {
						multiselect_values[menu_items_vars[menu_cursor_pos] ":" menu_item_value] = ""
						if(ENVIRON[menu_items_vars[menu_cursor_pos]] == "") {
							if(menu_item_value == "") menu_item_var_value = "\n"
							else menu_item_var_value = menu_item_value
						} else if(menu_item_value == "") {
							if(menu_item_var_value !~ /^\n/)
								menu_item_var_value = "\n" ENVIRON[menu_items_vars[menu_cursor_pos]]
						} else
							menu_item_var_value = ENVIRON[menu_items_vars[menu_cursor_pos]] "\n" menu_item_value
					}
					print ".ui_var_name=" menu_items_vars[menu_cursor_pos] "\n." menu_items_vars[menu_cursor_pos] "=" shell_escape(menu_item_var_value) "\n.continue"
					exit
				} else if(menu_items_type[menu_cursor_pos] == "c") {
					print ".ui_var_name=" menu_items_vars[menu_cursor_pos] "\n." menu_items_vars[menu_cursor_pos] "=" (is_checked(menu_cursor_pos) != (!(menu_cursor_pos in menu_items_values) || menu_items_values[menu_cursor_pos] ~ /^[1-9][0-9]*$/)) "\n.continue"
					exit
				} else if(menu_items_type[menu_cursor_pos] == "r") {
					print ".ui_var_name=" menu_items_vars[menu_cursor_pos] "\n." menu_items_vars[menu_cursor_pos] "=" shell_escape(menu_cursor_pos in menu_items_values ? menu_items_values[menu_cursor_pos] : menu_items[menu_cursor_pos]) "\n.continue"
					exit
				} else if(menu_items_type[menu_cursor_pos] == "b") {
					if(menu_cursor_pos in menu_items_values)
						print ".ui_choice=" shell_escape(menu_items_values[menu_cursor_pos])
					else
						print ".ui_choice=" shell_escape(menu_items[menu_cursor_pos])
					print ".ui_var_name=ui_choice\n.ui_event=select\n.continue"
					exit
				} else if(menu_items_type[menu_cursor_pos] == "q") {
					print ".ui_event=exit\n.continue"
					exit
				}
			} else if(action == "search_prev") {
				if(ENVIRON["ui_search"] != "") {
					search_text = tolower(ENVIRON["ui_search"])
					for(i = menu_cursor_pos - 1; i != menu_cursor_pos; i--) {
						if(i < 1) {
							if(menu_cursor_pos == menu_items_count) break
							i = menu_items_count
						}
						if(index(tolower(menu_items[i] (menu_items_type[i] == "i" ? " " ENVIRON[menu_items_vars[i]] : "")), search_text)) {
							menu_cursor_pos = i
							break
						}
					}
				}
			} else if(action == "search_next") {
				if(ENVIRON["ui_search"] != "") {
					search_text = tolower(ENVIRON["ui_search"])
					for(i = menu_cursor_pos + 1; i != menu_cursor_pos; i++) {
						if(i > menu_items_count) {
							if(menu_cursor_pos == 1) break
							i = 1
						}
						if(index(tolower(menu_items[i] (menu_items_type[i] == "i" ? " " ENVIRON[menu_items_vars[i]] : "")), search_text)) {
							menu_cursor_pos = i
							break
						}
					}
				}
			} else if(action == "search_edit") {
				event = "search_edit"
				ENVIRON["ui_value_l"] = ""
				ENVIRON["ui_value_r"] = ""
				print ".ui_event=search_edit\n.unset -v ui_value_l ui_value_r"
				print_at_end = "\33[?25h"
			}
			if(menu_cursor_pos < 1) menu_cursor_pos = 1
			else if(menu_cursor_pos > menu_items_count) menu_cursor_pos = menu_items_count
			for(i in menu_items_desc_raw) {
				menu_items_desc[i] = wordwrap(filter_printable(menu_items_desc_raw[i]), term_w, 1, 0, 0)
				menu_items_desc_height[i] = _lines_count
				if(_lines_count > desc_height) desc_height = _lines_count
			}
			if(ENVIRON["ui_title"] == "") title_height = 0
			else {
				title = wordwrap(filter_printable(ENVIRON["ui_title"]), term_w, 1, 0, 0)
				title_height = _lines_count
			}
			if(desc_height) {
				if(menu_cursor_pos in menu_items_desc) {
					desc = menu_items_desc[menu_cursor_pos]
					desc_raw = menu_items_desc_raw[menu_cursor_pos]
					desc_text_height = menu_items_desc_height[menu_cursor_pos]
				} else {
					desc = default_desc
					desc_raw = ENVIRON["ui_description"]
					desc_text_height = default_desc_height
				}
			}
			menu_height = menu_items_count
			additional_height = 2
			total_height = title_height + desc_height + menu_height + additional_height
			if(total_height < term_h) menu_height += term_h - total_height
			else if(total_height > term_h) {
				menu_height -= total_height - term_h
				total_height -= total_height - term_h
				if(menu_height < 3) {
					total_height += 3 - menu_height
					menu_height = 3
				}
				if(title_height && total_height > term_h) {
					old_title_height = title_height
					title_height -= total_height - term_h
					total_height -= total_height - term_h
					if(title_height < 1) {
						total_height += 1 - title_height
						title_height = 1
					}
					if(title_height != old_title_height)
						title = wordwrap(filter_printable(ENVIRON["ui_title"]), term_w, 1, title_height, 1)
				}
				if(desc_height && total_height > term_h) {
					old_desc_height = desc_height
					desc_height -= total_height - term_h
					total_height -= total_height - term_h
					if(desc_height < 1) {
						total_height += 1 - desc_height
						desc_height = 1
					}
					if(desc_height < desc_text_height) {
						desc_text_height = desc_height
						desc = wordwrap(filter_printable(desc_raw), term_w, 1, desc_height, 1)
					}
				}
			}
			scroll_total = menu_items_count - menu_height
			if(scroll_total < 0) scroll_total = 0
			scroll_offset = menu_cursor_pos - sprintf("%.0f", menu_height / 2)
			if(menu_height + scroll_offset > menu_items_count)
				scroll_offset = menu_items_count - menu_height
			if(scroll_offset < 0) scroll_offset = 0
			if(menu_height >= menu_items_count) scrollbar_height = 0
			else {
				scrollbar_height = sprintf("%.0f", menu_height * (menu_height / menu_items_count)) + 0
				if(!scrollbar_height) scrollbar_height = 1
				scrollbar_offset = sprintf("%.0f", (menu_height - scrollbar_height) * scroll_offset / scroll_total) + 0
			}
			print ".ui_menu_height_old=" menu_height
			print ".ui_menu_cursor_pos=" menu_cursor_pos
			print ""
			if(title_height) printf("\33]0;%s\007", wordwrap(filter_printable(ENVIRON["ui_title"]), 128, 0, 1, 1))
			printf("\33[0m\33[1;1H")
			if(title_height) printf("\33[1;37;44m%s\n", title)
			if(desc_height) {
				printf("\33[0;30;47m")
				if(desc_text_height) print desc
				for(i = desc_text_height; i < desc_height; i++) printf("%" term_w "s\n", "")
			}
			printf("\33[0;30;47m\342\224\214")
			for(i = 2; i < term_w; i++) printf("\342\224\200")
			printf("\33[1;37;47m\342\224\220\n")
			for(i = 1; i <= menu_height; i++) {
				menu_index = i + scroll_offset
				printf("\33[0;30;47m\342\224\202")
				if(menu_index <= menu_items_count) {
					if(menu_index == menu_cursor_pos && menu_items_type[menu_index] !~ /^[ipht]$/) printf("\33[1;37;44m")
					if(menu_items_type[menu_index] == "i" || menu_items_type[menu_index] == "p") {
						if(menu_items[menu_index] == "") {
							label_length = 0
							field_width = term_w - 3
						} else {
							label = wordwrap(filter_printable(menu_items[menu_index]), term_w - 7, 0, 1, 1)
							label_length = mblength(label)
							field_width = term_w - label_length - 4
							if(field_width < 3) field_width = 3
							if(label_length + field_width + 3 > term_w) {
								label_length = 0
								field_width = term_w - 3
							}
						}
						if(field_width < 3) field_width = 3
						if(menu_index == menu_cursor_pos && event == "edit") {
							if(menu_items_type[menu_index] == "p") {
								gsub(/./, "*", ENVIRON["ui_value_l"])
								gsub(/./, "*", ENVIRON["ui_value_r"])
							} else {
								gsub(/\n/, "\357\277\275", ENVIRON["ui_value_l"])
								gsub(/\n/, "\357\277\275", ENVIRON["ui_value_r"])
								ENVIRON["ui_value_l"] = filter_printable(ENVIRON["ui_value_l"])
								ENVIRON["ui_value_r"] = filter_printable(ENVIRON["ui_value_r"])
							}
							field_cursor_pos = mblength(ENVIRON["ui_value_l"]) + 1
							value = ENVIRON["ui_value_l"] ENVIRON["ui_value_r"]
							value_length = field_cursor_pos + mblength(ENVIRON["ui_value_r"]) - 1
							field_offset = field_cursor_pos - sprintf("%.0f", field_width / 2)
							if(field_offset + field_width > value_length) {
								field_offset = value_length - field_width
								if(field_cursor_pos == value_length + 1) field_offset++
							}
							if(field_offset < 0) field_offset = 0
							print_at_end = print_at_end "\33[" title_height + desc_height + i + 1 ";" (label_length ? label_length + 1 : 0) + field_cursor_pos - field_offset + 1 "H"
						} else {
							if(menu_items_type[menu_index] == "p") {
								value = ENVIRON[menu_items_vars[menu_index]]
								gsub(/./, "*", value)
							} else {
								value = filter_printable(ENVIRON[menu_items_vars[menu_index]])
								gsub(/\n/, "\357\277\275", value)
							}
							value_length = mblength(value)
							field_cursor_pos = 0
							field_offset = 0
						}
						if(field_offset) value = substr(value, mbcharpos(value, field_offset + 1))
						if(field_offset + field_width < value_length) value = substr(value, 1, mbcharpos(value, field_width + 1) - 1)
						if(label_length) {
							if(menu_index == menu_cursor_pos) printf("\33[0;30;46m")
							printf("%s ", label)
						}
						printf("\33[" (menu_index == menu_cursor_pos ? 1 : 0) ";37;44m%s", value)
						for(j = field_offset + field_width; j > value_length; j--) printf("_")
						printf("\33[4" (menu_index == menu_cursor_pos ? 6 : 7) "m ")
					} else if(menu_items_type[menu_index] == "m" || menu_items_type[menu_index] == "c")
						printf("[" (is_checked(menu_index) ? "v" : " ") "] %s", wordwrap(filter_printable(menu_items[menu_index]), term_w - 6, 1, 1, 1))
					else if(menu_items_type[menu_index] == "r")
						printf("(" (is_checked(menu_index) ? "*" : " ") ") %s", wordwrap(filter_printable(menu_items[menu_index]), term_w - 6, 1, 1, 1))
					else if(menu_items_type[menu_index] == "h") {
						if(menu_items[menu_index] == "") {
							printf("\33[0;30;4" (menu_index == menu_cursor_pos ? 6 : 7) "m")
							for(j = 2; j < term_w; j++) printf("\342\224\200")
						} else {
							label = wordwrap(filter_printable(" " menu_items[menu_index]), term_w - 3, 0, 1, 1)
							label_length = mblength(label)
							printf("\33[1;37;40m%s ", label)
							if(term_w - label_length > 3) printf("\33[4" (menu_index == menu_cursor_pos ? 6 : 7) "m%" term_w - label_length - 3 "s", "")
						}
					} else if(menu_items_type[menu_index] == "b" || menu_items_type[menu_index] == "q") {
						if(menu_items[menu_index] == "") printf("%" term_w - 2 "s", "")
						else printf("%s", wordwrap(filter_printable(menu_items[menu_index]), term_w - 2, 1, 1, 1))
					} else {
						printf("\33[4" (menu_index == menu_cursor_pos ? 6 : 7) "m")
						if(menu_items[menu_index] == "") printf("%" term_w - 2 "s", "")
						else printf("%s", wordwrap(filter_printable(menu_items[menu_index]), term_w - 2, 1, 1, 1))
					}
				} else printf("%" term_w - 2 "s", "")
				if(scrollbar_height && i > scrollbar_offset && i <= scrollbar_offset + scrollbar_height)
					printf("\33[0;30;40m\342\226\210\n")
				else
					printf("\33[1;37;47m\342\224\202\n")
			}
			printf("\33[0;30;47m\342\224\224\33[1;37;47m")
			if(event == "search_edit" || ENVIRON["ui_search"] != "") {
				field_width = sprintf("%.0f", (term_w - 2) / 2) + 0
				if(field_width < 20) {
					if(term_w < 22) field_width = term_w - 2
					else field_width = 20
				}
				if(event == "search_edit") {
					gsub(/\n/, " ", ENVIRON["ui_value_l"])
					gsub(/\n/, " ", ENVIRON["ui_value_r"])
					ENVIRON["ui_value_l"] = filter_printable(ENVIRON["ui_value_l"])
					ENVIRON["ui_value_r"] = filter_printable(ENVIRON["ui_value_r"])
					field_cursor_pos = mblength(ENVIRON["ui_value_l"]) + 1
					value = ENVIRON["ui_value_l"] ENVIRON["ui_value_r"]
					value_length = field_cursor_pos + mblength(ENVIRON["ui_value_r"]) - 1
					field_offset = field_cursor_pos - sprintf("%.0f", field_width / 2)
					if(field_offset + field_width > value_length) {
						field_offset = value_length - field_width
						if(field_cursor_pos == value_length + 1) field_offset++
					}
					if(field_offset < 0) field_offset = 0
					print_at_end = print_at_end "\33[" term_h ";" field_cursor_pos - field_offset + 1 "H"
				} else {
					value = filter_printable(ENVIRON["ui_search"])
					gsub(/\n/, " ", value)
					value_length = mblength(value)
					field_cursor_pos = 0
					field_offset = 0
				}
				if(field_offset) value = substr(value, mbcharpos(value, field_offset + 1))
				if(field_offset + field_width < value_length) value = substr(value, 1, mbcharpos(value, field_width + 1) - 1)
				printf("\33[" (event == "search_edit" ? 1 : 0) ";37;44m%s", value)
				for(j = field_offset + field_width; j > value_length; j--) printf("_")
				printf("\33[1;37;47m")
			} else field_width = 0
			for(i = field_width + 2; i < term_w; i++) printf("\342\224\200")
			printf("\342\224\230\33[0m%s", print_at_end)
		}' "$ui_stty_width" "$ui_stty_height")
		printf %s "$ui_output" | LC_ALL=C awk 'BEGIN { out = 0 } {
			if(out) {
				if(out == 2) print last_line
				else out = 2
				last_line = $0
			} else if($0 == "") out = 1
		} END { if(out == 2) printf("%s", last_line) }'
		ui_init=0
		eval "$(printf %s "$ui_output" | awk '{ if($0 == "") exit; sub(/^./, ""); print $0 }')"
		term_input
	done
	ui_callback() { :; }
	[ "$ui_event" != exit ]
}

log() {
	printf %s\\n "$scriptname: $*" >&2
}
err() {
	if [ $# -gt 1 ]; then
		log "$2"
	else
		log "$1"
	fi
	[ $# -gt 1 ] && exit "$1"
	return 1
}
checkutil() {
	unset -v checkutil__not_found_utils
	if [ ":$1" = :-s ]; then
		checkutil__silent=1
		shift
	else
		checkutil__silent=0
	fi
	[ ":$1" = :-- ] && shift
	set -- $*
	while [ $# -ne 0 ]; do
		{
			checkutil__util_path=$(command -v -- "$1") &&
			[ -n "$checkutil__util_path" ]
		} ||
			checkutil__not_found_utils=$checkutil__not_found_utils' '$1
		shift
	done
	[ -z "$checkutil__not_found_utils" ] || {
		checkutil__not_found_utils=${checkutil__not_found_utils# }
		[ $checkutil__silent -eq 0 ] &&
			err "\`$(printf %s\\n "$checkutil__not_found_utils" | sed 's/ /'\'', `/g; s/\(.*\), /\1 and /')' is not found in system, please install it; PATH=$PATH"
		return 1
	}
}

update_bashrc() {
	{
		[ $no_backup_bashrc -ne 0 ] || ! [ -e "$2/.bashrc" ] ||
		mv -f "$2/.bashrc" "$2/bashrc.old"
	} &&
	eval 'printf %s\\n "$'"$1"'" > "$2/.bashrc"' && {
		[ $# -lt 3 ] || chown -- "$3:$(id -gn -- "$3")" "$2/.bashrc"
	}
}

SIGNALS='HUP INT QUIT ILL ABRT FPE SEGV PIPE ALRM TERM USR1 USR2'
eval "signal_handler__register() { trap 'EXIT_CODE=\$?; trap '\\'\\'' \$SIGNALS; signal_handler EXIT' EXIT;$(
	LC_ALL=C awk -- 'BEGIN { for(i = 1; i < ARGC; i++) print "trap \47trap \47\134\47\134\47\47 $SIGNALS; signal_handler " ARGV[i] "; signal_handler__register\47 " ARGV[i] }' $SIGNALS
);}"



checkutil mktemp tar || exit 1
if checkutil -s curl; then
	request() {
		unset -v request__buf
		log "requesting URL $1 ..."
		if [ $# -gt 1 ]; then
			curl -sgLo "$2" "$1"
		else
			request__buf=$(curl -sgL "$1")
		fi || err "failed to request URL $1"
		[ -n "$request__buf" ] && printf %s\\n "$request__buf"
		return 0
	}
elif checkutil wget; then
	request() {
		unset -v request__buf
		log "requesting URL $1 ..."
		if [ $# -gt 1 ]; then
			wget -qO "$2" "$1"
		else
			request__buf=$(wget -qO- "$1")
		fi || err "failed to request URL $1"
		[ -n "$request__buf" ] && printf %s\\n "$request__buf"
		return 0
	}
else
	exit 1
fi

usage() {
	cat << END
Usage: $scriptname [<options>] ...

Options:
  -i          Install automatically without interactive mode.
  -S          System-wide install or update. If none of the -s or -u options is
              specified, the action is determined automatically.
  -U          Install or update in the user home directory. If none of the -s or
              -u options is specified, the action is determined automatically.
  -c          Update /etc/xbash/common-completions or ~/.xbash/common-completions
              file if it exists (system-specific completions)
  -u          Install .bashrc for the current user
  -a          Install .bashrc to the home directories of all users in the
  -s          Install .bashrc to /etc/skel (only for system-wide installation)
              system (only for system-wide installation)
  -b          Do not create a .bashrc backup before replacing
  -f          Install or update fzf command-line fuzzy finder binary.
  -h, --help  Display this help and exit
END
}

unset -v tmpdir
scriptname=$(basename -- "$0")
euid=$(id -u) || exit 1
in_progress=0
interactive=1
install_system_wide=
update_common_completions=0
install_bashrc_user=0
install_bashrc_all_users=0
install_bashrc_skel=0
no_backup_bashrc=0
install_fzf=0


if [ ":$1" = :--help ] || [ ":$1" = :-h ]; then
	usage; exit 0
else while getopts iSUcusabf OPT; do case $OPT in
	i) interactive=0;;
	S) install_system_wide=1;;
	U) install_system_wide=0;;
	c) update_common_completions=1;;
	u) install_bashrc_user=1;;
	a) install_bashrc_all_users=1;;
	s) install_bashrc_skel=1;;
	b) no_backup_bashrc=1;;
	f) install_fzf=1;;
	?) exit 1;;
esac; done; fi
shift $((OPTIND - 1))
OPTIND=1
[ $# -eq 0 ] || err 1 'Invalid number of arguments'

if [ -z "$install_system_wide" ]; then
	if [ $euid -eq 0 ]; then
		install_system_wide=1
	else
		install_system_wide=0
	fi
elif [ $install_system_wide -ne 0 ] && [ $euid -ne 0 ]; then
	err 1 'unable to perform system-wide installation without root privileges'
fi


signal_handler() {
	case $1 in
	EXIT)
		ui_mode off
		[ $in_progress -ne 0 ] && log 'installation aborted'
		[ -n "$tmpdir" ] && {
			log 'removing temporary directory ...'
			rm -rf -- "$tmpdir"
		}
		if [ $EXIT_CODE -eq 0 ]; then
			exit $in_progress
		else
			exit $EXIT_CODE
		fi
		;;
	*)
		log "received SIG$1"
		exit
		;;
	esac
}
signal_handler__register


[ $interactive -ne 0 ] && {
	title='xbash installer'
	[ $euid -eq 0 ] || title=$title' (not as root)'
	title="$title - $USER@$(uname -n)"
	[ $install_fzf -ne 0 ] || checkutil -s fzf || install_fzf=1
	ui "$title" 'Use arrow keys, Tab and Shift+Tab to navigate, "Return" or "Space" to select and "q" to quit' "$(
		if [ $euid -eq 0 ]; then
			printf %s\\n 'rinstall_system_wide:System-wide install or update' v1
		else
			printf %s\\n 't( ) System-wide install or update (in the /usr/local directory, must be run as root)'
		fi
		)"'
		rinstall_system_wide:Install or update in the user home directory (~/.local and ~/.xbash directories)
		v0
		t
		cupdate_common_completions:Update /etc/xbash/common-completions or ~/.xbash/common-completions file if it exists (system-specific completions)
		cinstall_bashrc_user:Install .bashrc for the current user
		cinstall_bashrc_all_users:Install .bashrc to the home directories of all users in the system (only for system-wide installation)
		cinstall_bashrc_skel:Install .bashrc to /etc/skel (only for system-wide installation)
		cno_backup_bashrc:Do not create a .bashrc backup before replacing
		t
		cinstall_fzf:Install or update fzf command-line fuzzy finder binary
		t
		bInstall
		qQuit' || exit 0
	ui_mode off
}


in_progress=1
{ tmpdir=$(mktemp -d) && cd -- "$tmpdir"; } || exit 1

[ $install_fzf -ne 0 ] && {
	sys_arch=$(uname -sm)
	case $sys_arch in
	Linux\ armv5*)   sys=linux;   arch=arm5  ;;
	Linux\ armv6*)   sys=linux;   arch=arm6  ;;
	Linux\ armv7*)   sys=linux;   arch=arm7  ;;
	Linux\ armv8*)   sys=linux;   arch=arm8  ;;
	Linux\ aarch64*) sys=linux;   arch=arm8  ;;
	Linux\ *64)      sys=linux;   arch=amd64 ;;
	Linux\ *86)      sys=linux;   arch=386   ;;
	FreeBSD\ *64)    sys=freebsd; arch=amd64 ;;
	FreeBSD\ *86)    sys=freebsd; arch=386   ;;
	OpenBSD\ *64)    sys=openbsd; arch=amd64 ;;
	OpenBSD\ *86)    sys=openbsd; arch=386   ;;
	Darwin\ *64)     sys=darwin;  arch=amd64 ;;
	Darwin\ *86)     sys=darwin;  arch=386   ;;
	CYGWIN*\ *64)    sys=windows; arch=amd64 ;;
	MINGW*\ *86)     sys=windows; arch=386   ;;
	MINGW*\ *64)     sys=windows; arch=amd64 ;;
	MSYS*\ *86)      sys=windows; arch=386   ;;
	MSYS*\ *64)      sys=windows; arch=amd64 ;;
	Windows*\ *86)   sys=windows; arch=386   ;;
	Windows*\ *64)   sys=windows; arch=amd64 ;;
	*) err 1 "unable to install fzf for \`$sys_arch'";;
	esac
	url=$(
		request https://api.github.com/repos/junegunn/fzf-bin/releases/latest |
		tr '\t,{}[]' ' \n\n\n\n\n' |
		sed -n 's/^ *"browser_download_url" *: *"\(https\{0,1\}:\/\/[^"]*'"$sys[^\"/]*$arch"'[^"/]*\)".*/\1/; tp; b; :p p; q'
	)
	[ -z "$url" ] && err 1 'unable to get fzf download url'
	ext=$(printf %s\\n "$url" | sed 's/.*\.\(tar\.gz\|tgz\|zip\)$/\1/')
	[ -z "$ext" ] && err 1 'unable to install fzf, because archive file extension is unknown'
	mkdir fzf && cd fzf &&
	request "$url" "fzf.$ext" &&
	if [ ":$ext" = :zip ]; then
		unzip -o "fzf.$ext"
	else
		tar -xzf "fzf.$ext"
	fi &&
	rm -f "fzf.$ext" &&
	cd ..
	[ $? -eq 0 ] || exit 1
	[ -f fzf/fzf ] || err 1 'file \`fzf'\'' does not exist in the downloaded archive'
}

url=$(
	request https://api.github.com/repos/10geek/xbash/releases/latest |
	tr '\t,{}[]' ' \n\n\n\n\n' |
	sed -n 's/^ *"tarball_url" *: *"\(https\{0,1\}[^"]*\)".*/\1/; tp; b; :p p; q'
)
[ -z "$url" ] && err 1 'unable to get xbash download url'

mkdir xbash && cd xbash &&
request "$url" xbash.tar.gz &&
tar -xzf xbash.tar.gz &&
rm -f xbash.tar.gz &&
mv -f -- "$(find . -type d -path './*' -prune | head -n1)" unpacked &&
cd ..
[ $? -eq 0 ] || exit 1
[ -d xbash/unpacked/xbash ] || err 1 'directory \`xbash'\'' does not exist in the downloaded archive'

log 'installing xbash'
cd xbash/unpacked/xbash &&
if [ $install_system_wide -ne 0 ]; then
	{
		[ -d /usr/local/lib/bash ] || mkdir -p /usr/local/lib/bash
	} &&
	cp usr/local/lib/bash/xbash.bash /usr/local/lib/bash &&
	if ! [ -d /usr/local/share/xbash ]; then
		mkdir -p /usr/local/share &&
		cp -R usr/local/share/xbash /usr/local/share
	else
		{
			! [ -d /usr/local/share/xbash/base-completions ] ||
			rm -rf /usr/local/share/xbash/base-completions
		} &&
		cp -R usr/local/share/xbash/base-completions /usr/local/share/xbash && {
			errors=$(find /usr/local/share/xbash \
				! -path /usr/local/share/xbash -prune \
				-type f -exec rm -f {} \; 2>&1
			)
			[ -z "$errors" ] || { printf %s\\n "$errors" >&2; false; }
		} && {
			errors=$(find usr/local/share/xbash \
				! -path usr/local/share/xbash -prune \
				-type f -exec cp {} /usr/local/share/xbash \; 2>&1
			)
			[ -z "$errors" ] || { printf %s\\n "$errors" >&2; false; }
		}
	fi &&
	if [ -d /etc/xbash ]; then
		{
			[ -e /etc/xbash/common-completions ] &&
			[ $update_common_completions -eq 0 ]
		} || cp etc/xbash/common-completions /etc/xbash
	else
		cp -R etc/xbash /etc
	fi && {
		[ -e /etc/xbashrc ] || cp etc/xbashrc /etc
	}
	[ $? -eq 0 ] || exit 1
	[ "$install_bashrc_user$install_bashrc_skel$install_bashrc_all_users" = 000 ] || {
		bashrc=$(cat etc/skel/.bashrc) &&
		{ [ $install_bashrc_user -eq 0 ] || update_bashrc bashrc ~; } &&
		{ [ $install_bashrc_skel -eq 0 ] || printf %s\\n "$bashrc" > /etc/skel/.bashrc; } &&
		{ [ $install_bashrc_all_users -eq 0 ] || {
			success=1
			if command -v getent > /dev/null
			then getent passwd
			else cat /etc/passwd
			fi | awk -F: "$(
				awk 'BEGIN { ORS = ""; pre = "" } {
					if(NF != 2) next
					if($1 == "UID_MIN") { print "$3 >= " int($2); pre = " && " }
					else if($1 == "UID_MAX") print pre "$3 < " int($2)
				}' /etc/login.defs 2>/dev/null ||
				printf %s '$3 >= 1000 && $3 < 60000'
			)"' && $1 != "nobody" { print $1; print $6 }' |
			while IFS= read -r username && IFS= read -r homedir; do
				update_bashrc bashrc "$homedir" "$username"
			done
		}; }
	}
else
	{
		[ -d ~/.local/lib/bash ] || mkdir -p ~/.local/lib/bash
	} &&
	cp usr/local/lib/bash/xbash.bash ~/.local/lib/bash &&
	if ! [ -d ~/.xbash ]; then
		cp -R usr/local/share/xbash ~/.xbash
	else
		{
			! [ -d ~/.xbash/base-completions ] ||
			rm -rf ~/.xbash/base-completions
		} &&
		cp -R usr/local/share/xbash/base-completions ~/.xbash && {
			errors=$(find usr/local/share/xbash \
				! -path usr/local/share/xbash -prune \
				-type f -exec cp {} ~/.xbash \; 2>&1
			)
			[ -z "$errors" ] || { printf %s\\n "$errors" >&2; false; }
		}
	fi && {
		{
			[ -e /etc/xbash/common-completions ] &&
			[ $update_common_completions -eq 0 ]
		} || cp etc/xbash/common-completions ~/.xbash
	}
	[ $? -eq 0 ] || exit 1
	[ $install_bashrc_user -eq 0 ] || {
		bashrc=$(sed 's/\/usr\/local\/lib\/bash\/xbash\.bash/~\/.local\/lib\/bash\/xbash\.bash/g' etc/skel/.bashrc) &&
		update_bashrc bashrc ~
	}
fi &&
cd ../../..
[ $? -eq 0 ] || exit 1

[ $install_fzf -ne 0 ] && {
	log 'installing fzf'
	if [ $install_system_wide -ne 0 ]; then
		install_dir=/usr/local/bin
	else
		install_dir=$HOME/.local/bin
	fi
	{
		[ -d "$install_dir" ] || mkdir -p "$install_dir"
	} &&
	cp fzf/fzf "$install_dir" &&
	chmod +x "$install_dir/fzf"
	[ $? -eq 0 ] || exit 1
}

in_progress=0
log done
