#!/usr/bin/env bash

msg() { echo "--- $@" 1>&2; }
detail() { echo "	$@" 1>&2; }
verlte() {
  [ "$1" = `echo -e "$1\n$2" | sort -t '.' -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -n1` ]
}


command -v stack >/dev/null
if [ $? -ne 0 ] ; then
  msg "Installer requires Stack. Installation instructions:"
  msg "https://github.com/commercialhaskell/stack#how-to-install"
  exit 1
fi

msg "Installing system package dependencies"
command -v brew >/dev/null
if [ $? -eq 0 ] ; then
  msg "homebrew detected"
  brew install git make vim ctags
fi
command -v apt-get >/dev/null
if [ $? -eq 0 ] ; then
  msg "apt-get detected"
  sudo apt-get install -y git make vim libcurl4-openssl-dev exuberant-ctags
fi
command -v dnf >/dev/null
if [ $? -eq 0 ] ; then
  msg "dnf detected"
  sudo dnf install -y git make vim ctags libcurl-devel zlib-devel
  DNF=1
fi
command -v yum >/dev/null
if [ $? -eq 0 ] && [ $DNF -ne 1 ] ; then
  msg "yum detected"
  sudo yum install -y git make vim ctags libcurl-devel zlib-devel
fi

for i in ctags curl-config git make vim; do
  command -v $i >/dev/null
  if [ $? -ne 0 ] ; then
    msg "Installer requires ${i}. Please install $i and try again."
    exit 1
  fi
done

VIM_VER=$(vim --version | sed -n 's/^.*IMproved \([^ ]*\).*$/\1/p')

if ! verlte '7.4' $VIM_VER ; then
  msg "Detected vim version \"$VIM_VER\""
  msg "However version 7.4 or later is required. Aborting."
  exit 1
fi

endpath="$HOME/.haskell-vim-now"

if [ ! -e $endpath/.git ]; then
  msg "Cloning begriffs/haskell-vim-now"
  git clone https://github.com/begriffs/haskell-vim-now.git $endpath
else
  msg "Existing installation detected"
  msg "Updating from begriffs/haskell-vim-now"
  cd $endpath && git pull
fi

if [ -e ~/.vim/colors ]; then
  msg "Preserving color scheme files"
  cp -R ~/.vim/colors $endpath/colors
fi

today=`date +%Y%m%d_%H%M%S`
msg "Backing up current vim config using timestamp $today"
for i in $HOME/.vim $HOME/.vimrc $HOME/.gvimrc; do [ -e $i ] && mv $i $i.$today && detail "$i.$today"; done

msg "Creating symlinks"
detail "~/.vimrc -> $endpath/.vimrc"
detail "~/.vim   -> $endpath/.vim"
ln -sf $endpath/.vimrc $HOME/.vimrc
if [ ! -d $endpath/.vim/bundle ]; then
  mkdir -p $endpath/.vim/bundle
fi
ln -sf $endpath/.vim $HOME/.vim

if [ ! -e $HOME/.vim/autoload/plug.vim ]; then
  msg "Installing vim-plug"
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

msg "Installing plugins using vim-plug..."
vim -T dumb -E -u $endpath/.vimrc +PlugUpgrade +PlugUpdate +PlugClean! +qall

msg "Setting up GHC if needed"
stack setup

msg "Adding extra stack deps if needed"
DEPS_REGEX='s/extra-deps: \[\]/extra-deps: [cabal-helper-0.6.1.0, pure-cdb-0.1.1]/'
# upgrade from a previous installation
DEPS_UPGRADE_REGEX='s/cabal-helper-0.5.3.0/cabal-helper-0.6.1.0/g'
sed -i.bak "$DEPS_REGEX" ~/.stack/global-project/stack.yaml || sed -i.bak "$DEPS_REGEX" ~/.stack/global/stack.yaml
sed -i.bak "$DEPS_UPGRADE_REGEX" ~/.stack/global-project/stack.yaml || sed -i.bak "$DEPS_UPGRADE_REGEX" ~/.stack/global/stack.yaml
rm -f ~/.stack/global/stack.yaml.bak ~/.stack/global-project/stack.yaml.bak

msg "Installing helper binaries"
stack --resolver nightly install ghc-mod hdevtools hasktags codex hscope pointfree pointful hoogle stylish-haskell

msg "Installing git-hscope"
cp $endpath/git-hscope ~/.local/bin

msg "Building Hoogle database..."
~/.local/bin/hoogle data

msg "Setting git to use fully-pathed vim for messages..."
git config --global core.editor $(which vim)

msg "Configuring codex to search in stack..."
cat > $HOME/.codex <<EOF
hackagePath: $HOME/.stack/indices/Hackage/
tagsFileHeader: false
tagsFileSorted: false
tagsCmd: hasktags --extendedctag --ignore-close-implementation --ctags --tags-absolute --output='\$TAGS' '\$SOURCES'
EOF
