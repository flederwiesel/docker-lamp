export PS1='\[\e]0;\w\a\]\n\[\e[31m\]\u@\[\033[1;33m\]\h\[\033[m\] \[\e[36m\]\w\[\e[0m\]\$ '
export PS4='\[\033[36m\]${BASH_SOURCE[0]}($LINENO)\[\033[m\]: ${FUNCNAME[0]:+ \[\033[1;37m\]${FUNCNAME[0]}($@)\[\033[m\]:}\n '

alias grep='grep --color'
alias ll='ls -AlF --color --time-style="+%F %T"'
