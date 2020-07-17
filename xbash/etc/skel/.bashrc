[ -e /etc/bashrc ] && . /etc/bashrc
. /usr/local/lib/bash/xbash.bash || return

[ -d ~/.local/bin ] && xbash_pathvarmunge PATH ~/.local/bin
export PATH

xbash_shell_preset

export EDITOR=nano
unset -v HISTFILE
HISTCONTROL=erasedups:ignorespace
HISTSIZE=1000

#[ -f /etc/xbash-snippets.bash ] && XBASH_SNIPPETS+=$(cat /etc/xbash-snippets.bash)
#XBASH_SNIPPETS+='
#
#'
