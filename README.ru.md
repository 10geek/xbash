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

- Работа в командной оболочке недостаточно продуктивна и занимает много времени?
- Слишком многое приходится набирать вручную из-за неэффективности дополнения по <kbd>Tab</kbd>?
- Приходится запоминать огромное количество имён alias'ов, команд, субкоманд, опций и т. д.?
- Проводите слишком много времени в man-страницах и --help'ах?
- Zsh не подходит из-за перегруженности архитектуры и невозможности установить его на сервер при отсутствии root привилегий?

Если хоть на один вопрос вы ответили утвердительно, то вы попали по адресу!

## Оглавление
- [Установка](#установка)
	- [С использованием установочного скрипта](#с-использованием-установочного-скрипта)
	- [Ручная установка](#ручная-установка)
- [Ключевые особенности](#ключевые-особенности)
- [Демо](#демо)
- [Структура файлов и каталогов](#структура-файлов-и-каталогов)
	- [Общесистемная установка](#общесистемная-установка)
	- [Установка в домашнем каталоге пользователя](#установка-в-домашний-каталог-пользователя)
	- [Файлы и каталоги](#файлы-и-каталоги)

## Установка

### С использованием установочного скрипта

Первоначальная установка:
```sh
sh -c 'eval "$(wget https://raw.githubusercontent.com/10geek/xbash/master/xbash-install.sh -O-)"' xbash-install -uas
```

Обновление:
```sh
sh -c 'eval "$(wget https://raw.githubusercontent.com/10geek/xbash/master/xbash-install.sh -O-)"' xbash-install
```

### Ручная установка
См. раздел [&laquo;Структура файлов и каталогов&raquo;](#структура-файлов-и-каталогов) и пример конфигурации `.bashrc` в [xbash/etc/skel/.bashrc](xbash/etc/skel/.bashrc).

## Ключевые особенности
- Дополнение в зависимости от контекста (имя переменной, значение переменной, перенаправление, имя пользователя после "~", подстановка команд с произвольной вложенностью и пр.);
- Раскрытие неполных путей: `/u/l/sh`<kbd>Tab</kbd> => `/usr/local/share`;
- Рекурсивный поиск файлов и каталогов:
	- Все файлы и каталоги: `/path/**`<kbd>Tab</kbd>;
	- Все каталоги `/path/**/`<kbd>Tab</kbd>;
	- Все пути, начинающиеся на "/path/suffix": `/path/suffix**`<kbd>Tab</kbd>;
- Рекурсивный поиск файлов и каталогов с сортировкой по времени модификации (синтаксис аналогичен предыдущему): `/path/***`<kbd>Tab</kbd>;
- Раскрытие glob'ов: `.bash*`<kbd>Tab</kbd> => `.bash_history .bash_logout .bashrc`;
- Правильная обработка кавычек и автоматическое экранирование строк, заключённых в них;
- Корректное дополнение имён файлов и каталогов с произвольными символами в имени: `rm weird`<kbd>Tab</kbd> => `rm weird$'\n'file$'\t'name`;
- Правильная работа дополнения для коротких и длинных (GNU-style) опций и их значений (`-ovalue -o value --opt value --opt=value`);
- Генерация дополнения опций из вывода `<utilname> --help` или man-страниц;
- Автоматическое закрытие кавычек и скобок при вводе;
- Множественный выбор результатов дополнения;
- Сниппеты;
- Поиск по истории команд (<kbd>Ctrl+S</kbd>, <kbd>Ctrl+R</kbd>);
- Исправление неправильно набранных команд по <kbd>Tab</kbd>;
- Выполнение действий с группами символов (backward-group, forward-group, backward-kill-group, kill-group), поведение которых настраивается с помощью регулярного выражения;
- Не конфликтует с bash-completion и вызывает его для получения вариантов дополнения при отсутствии собственной функции дополнения (`xbash_comp_<cmdname>`) для какой-либо команды;
- Поддержка множества различных реализаций интерактивных меню: [fzf](https://github.com/junegunn/fzf), [skim](https://github.com/lotabout/skim), [heatseeker](https://github.com/rschmitt/heatseeker), [fzy](https://github.com/jhawthorn/fzy), [peco](https://github.com/peco/peco), [pick](https://github.com/mptre/pick), [pmenu](https://github.com/sgtpep/pmenu), [percol](https://github.com/mooz/percol), [sentaku](https://github.com/rcmdnk/sentaku);
- Настраиваемый prompt с отображением кода завершения предыдущей команды и количества фоновых задач;
- Дополнение PID процессов, запущенных из текущей командной оболочки, для таких команд, как `kill`.

## Демо
[![Demo](https://raw.githubusercontent.com/10geek/xbash/master/docs/img/demo-preview.png)](https://10geek.github.io/xbash/demo.html)

## Структура файлов и каталогов

### Общесистемная установка
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

### Установка в домашнем каталоге пользователя
- `~/.local/lib/bash/xbash.bash`
- `~/.xbash/`
	- `base-completions/`
	- `completions/`
	- `plugins/`
	- `common-base-completions`
	- `common-completions`

### Файлы и каталоги
Файл или каталог | Описание
--- | ---
`xbash.bash` | Основной файл.
`xbashrc` | Общесистемный файл конфигурации.
`{{/usr/{,local/}share,/etc}/xbash,~/.xbash}/*` | Файлы, подключаемые на этапе инициализации.
`common-base-completions` | Базовый набор дополнений фреймворка.
`common-completions` | Набор дополнений, индивидуальный для каждой конкретной системы.
`base-completions/*` | Базовый набор динамически подключаемых модулей дополнений.
`completions/*` | Динамически подключаемые модули дополнений. Используется для файлов, поставляемых с устанавливаемым программным обеспечением.
`plugins/*` | Файлы, подключаемые на этапе инициализации. Используется для файлов, поставляемых с устанавливаемым программным обеспечением.

На этапе инициализации выполняется подключение файлов из следующих каталогов в указанном порядке:
1. `/etc/xbashrc`
2. `/usr/share/xbash`
3. `/usr/share/xbash/plugins`
4. `/usr/local/share/xbash`
5. `/usr/local/share/xbash/plugins`
6. `/etc/xbash`
7. `/etc/xbash/plugins`
8. `~/.xbash`
9. `~/.xbash/plugins`

При отсутствии функции дополнения (`xbash_comp_<cmdname>`) для команды выполняется поиск модуля дополнения в следующих каталогах в указанном порядке до первого найденного:
1. `~/.xbash/completions/`
2. `/etc/xbash/completions/`
3. `/usr/local/share/xbash/completions/`
4. `/usr/share/xbash/completions/`
5. `{/usr/{,local/}share/xbash,~/.xbash}/base-completions/` (в зависимости от расположения основного файла)
