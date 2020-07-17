# xbash

```
      ____        ____            ____
  ___/ / /_  __ __   /  ___ _ ___    /
 ___  . __/  \ \ // _ \/ _ `/(_- `/ _ \
___    __/  /_\_\/_.__/\_,_//___)/_//_/
  /_/_/
```

An extensible framework for interactive bash shell with advanced completion engine.

*Read this in other languages: [English](README.md), [Русский](README.ru.md).*

---

- Working in the command shell is not productive enough and takes a long time?
- Too much manual typing due to ineffective <kbd>Tab</kbd> completion?
- You have to memorize a huge number of alias names, commands, subcommands, options, etc.?
- Spending too much time in man pages and --helps?
- Zsh is not suitable due to overloaded architecture and inability to install it on the server without root privileges?

If at least one question you answered &ldquo;yes&rdquo;, then you've come to the right place!

## Table of Contents
- [Installation](#installation)
	- [Using the installation script](#using-the-installation-script)
	- [Manual installation](#manual-installation)
- [Key features](#key-features)
- [Demo](#demo)
- [Files and directories structure](#files-and-directories-structure)
	- [System-wide installation](#system-wide-installation)
	- [Installation in the user home directory](#installation-in-the-user-home-directory)
	- [Files and directories](#files-and-directories)

## Installation

### Using the installation script

First installation:
```sh
sh -c 'eval "$(wget https://raw.githubusercontent.com/10geek/xbash/master/xbash-install.sh -O-)"' xbash-install -uas
```

Update:
```sh
sh -c 'eval "$(wget https://raw.githubusercontent.com/10geek/xbash/master/xbash-install.sh -O-)"' xbash-install
```

### Manual installation
See the [&ldquo;Files and directories structure&rdquo;](#files-and-directories-structure) section and example of the `.bashrc` configuration in [xbash/etc/skel/.bashrc](xbash/etc/skel/.bashrc).

## Key features
- Completion depending on the context (variable name, variable value, redirection, user name after "~", command substitution with arbitrary nesting, etc.);
- Incomplete paths expansion: `/u/l/sh`<kbd>Tab</kbd> => `/usr/local/share`;
- Recursive files and directories searching:
	- All files and directories: `/path/**`<kbd>Tab</kbd>;
	- All directories `/path/**/`<kbd>Tab</kbd>;
	- All paths that starts with "/path/suffix": `/path/suffix**`<kbd>Tab</kbd>;
- Recursive files and directories searching with sorting by modification time (the syntax is similar to the previous one): `/path/***`<kbd>Tab</kbd>;
- Globs expansion: `.bash*`<kbd>Tab</kbd> => `.bash_history .bash_logout .bashrc`;
- Correct handling of quotes and automatic escaping of strings enclosed in them;
- Correct completion of file and directory names with arbitrary characters in the name: `rm weird`<kbd>Tab</kbd> => `rm weird$'\n'file$'\t'name`;
- Correct completion for short and long (GNU-style) options and their values (`-ovalue -o value --opt value --opt=value`);
- Generating options completions from the output of `<utilname> --help` or man pages;
- Automatic closing of quotation marks and brackets when typing;
- Multiple selection of the completion results;
- Snippets;
- Search through the command history (<kbd>Ctrl+S</kbd>, <kbd>Ctrl+R</kbd>);
- Correction of mistyped commands with <kbd>Tab</kbd>;
- Performing actions on groups of characters (backward-group, forward-group, backward-kill-group, kill-group) whose behavior is customizable with a regular expression;
- Does not conflict with bash-completion and calls it to get completions when there is no native completion function (`xbash_comp_<cmdname>`) for whatever command;
- Support of many different implementations of interactive menus: [fzf](https://github.com/junegunn/fzf), [skim](https://github.com/lotabout/skim), [heatseeker](https://github.com/rschmitt/heatseeker), [fzy](https://github.com/jhawthorn/fzy), [peco](https://github.com/peco/peco), [pick](https://github.com/mptre/pick), [pmenu](https://github.com/sgtpep/pmenu), [percol](https://github.com/mooz/percol), [sentaku](https://github.com/rcmdnk/sentaku);
- Customizable prompt showing the exit status of the previous command and the number of background jobs;
- PID completion of processes running in the current shell for commands such as `kill`.

## Demo
[![Demo](https://raw.githubusercontent.com/10geek/xbash/master/docs/img/demo-preview.png)](https://10geek.github.io/xbash/demo.html)

## Files and directories structure

### System-wide installation
- `/etc/`
	- `xbash/`
		- `completions/`
		- `plugins/`
		- `common-completions`
	- `xbashrc`
- `/usr/local/`, `/usr/`
	- `lib/bash/xbash.bash`
	- `share/xbash/`
		- `base-completions/`
		- `completions/`
		- `plugins/`
		- `common-base-completions`
- `~/.xbash/`
	- `completions/`
	- `plugins/`

### Installation in the user home directory
- `~/.local/lib/bash/xbash.bash`
- `~/.xbash/`
	- `base-completions/`
	- `completions/`
	- `plugins/`
	- `common-base-completions`
	- `common-completions`

### Files and directories
File or directory | Description
--- | ---
`xbash.bash` | Main file.
`xbashrc` | System-wide configuration file.
`{{/usr/{,local/}share,/etc}/xbash,~/.xbash}/*` | Files included at initialization.
`common-base-completions` | A basic set of framework completions.
`common-completions` | A set of completions, individual for each specific system.
`base-completions/*` | A basic set of dynamically loadable completion modules.
`completions/*` | Dynamically loadable completion modules. Used for files that ship with installed software.
`plugins/*` | Files included at initialization. Used for files that ship with installed software.

During the initialization, files from the following directories are included in the specified order:
1. `/etc/xbashrc`
2. `/usr/share/xbash`
3. `/usr/share/xbash/plugins`
4. `/usr/local/share/xbash`
5. `/usr/local/share/xbash/plugins`
6. `/etc/xbash`
7. `/etc/xbash/plugins`
8. `~/.xbash`
9. `~/.xbash/plugins`

If there is no completion function (`xbash_comp_<cmdname>`) for the command, the completion module is searched for in the following directories in the specified order up to the first one found:
1. `~/.xbash/completions/`
2. `/etc/xbash/completions/`
3. `/usr/local/share/xbash/completions/`
4. `/usr/share/xbash/completions/`
5. `{/usr/{,local/}share/xbash,~/.xbash}/base-completions/` (depending on the main file location)
