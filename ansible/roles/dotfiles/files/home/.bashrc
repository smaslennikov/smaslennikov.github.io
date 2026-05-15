# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

########  paths

export GEM_HOME="$HOME/gems"
export GOPATH=$HOME/go
export LD_LIBRARY_PATH=/usr/local/lib
export PATH="$HOME/bin:$HOME/local/bin:/usr/local/bin:$HOME/adb-fastboot/platform-tools:$HOME/gems/bin:$PATH:$HOME/.local/bin:$PATH:/sbin:/usr/sbin/:/usr/local/go/bin:$HOME/.local/bin:$HOME/go/bin"

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(rbenv init - --no-rehash zsh)"

####### bash options

HISTCONTROL=ignoreboth
shopt -s histappend
shopt -s checkwinsize

export HISTSIZE=200000
export HISTFILESIZE=400000
export HISTTIMEFORMAT="%h/%d -- %H:%M:%S "

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# for osx duh
if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi

[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion
[ -f /etc/profile.d/bash_completion.sh ] && . /etc/profile.d/bash_completion.sh

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

########  aliases and tools configs

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
export ANSIBLE_NOCOWS=1
export ARCH='x64'
export EDITOR="vim"
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

unset SSH_AGENT_PID
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
export GPG_TTY=$(tty)

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

[ -f $HOME/.travis/travis.sh ] && source $HOME/.travis/travis.sh
export GITPAGER=less
source <(kubectl completion bash)
alias beep='mpv /usr/share/sounds/gnome/default/alerts/sonar.ogg --loop'
export DOCKER_HOST=unix:///run/user/1000/docker.sock
export GO111MODULE=on

alias la='ls -A'
alias l='ls -CF'
alias ll="ls -lah"
alias ipa="ip a"
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

function _branch_show() {
  git branch 2> /dev/null | grep -e "^*" | cut -d' ' -f 2 | sed -e 's/$/ /g'
}

function _foreground_calc {
  # thanks centos
  shasum_cmd=$(which shasum  2>/dev/null || echo sha1sum)
  # reject these colors for being too dark
  local reject=([0]=a [16]=a [17]=a [18]=a [19]=a [232]=a [233]=a [234]=a [235]=a [236]=a [237]=a [238]=a)
  echo "$1" | $shasum_cmd | while read -n2 num; do
  local num=$((16#$num))
  if [ -z "${reject[$num]}" ]; then
    echo $num
    return
  fi
  done
}
export PS1='\[\033k\033\\\]\[\e[32m\]\u@\[\e[38;5;${hostnamecolor}m\]\h \[\e[32m\]\w \[\033[33m\]$(_branch_show)\[\e[32m\]\j\[\e[0m\] \$ '
export hostnamecolor=$(_foreground_calc $HOSTNAME)

######## let's gooo

fortune | cowsay -y
echo "~~~~~~~~~~~^^^^^^^^^^^^^^^^^^~~~~~~~~~"
uptime
echo
screen -ls

######## important trash
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/legacy_credentials/*/adc.json
