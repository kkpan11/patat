🥔 patat
========

![CI](https://github.com/jaspervdj/patat/actions/workflows/haskell-ci.yml/badge.svg) [![Hackage](https://img.shields.io/hackage/v/patat.svg)](https://hackage.haskell.org/package/patat) [![GitHub tag](https://img.shields.io/github/tag/jaspervdj/patat.svg)]()

`patat` (**P**resentations **A**top **T**he **A**NSI **T**erminal) is a
feature-rich presentation tool that runs in the terminal.

- Understands most markdown extensions and many other input formats
  (rST, Org-mode...) by building on top of [Pandoc].
- [Evaluate code snippets and show the result](#evaluating-code).
- Syntax highlighting for nearly one hundred languages generated from [Kate]
  syntax files.
- [Automatically reload](#running) your slides as you edit them.
- Display [speaker notes](#speaker-notes) in a second window or monitor.
- [Incremental slide display](#fragmented-slides).
- Experimental [images](#images) support.
- [Transition effects](#transitions).
- Supports [smart slide splitting](#input-format).
- [Auto advancing](#auto-advancing) with configurable delay.
- [Centering](#centering) and [re-wrapping](#line-wrapping) text to terminal
  width with proper indentation.
- [Theming](#theming) support including 24-bit RGB.
- Highly portable as it only requires an ANSI terminal as opposed to
  something like `ncurses`.

![screenshot](extra/demo.gif?raw=true)

[Kate]: https://kate-editor.org/
[Pandoc]: http://pandoc.org/

Table of Contents
-----------------

-   [Table of Contents](#table-of-contents)
-   [Installation](#installation)
    -   [Pre-built packages](#pre-built-packages)
    -   [From source](#from-source)
-   [Running](#running)
-   [Options](#options)
-   [Controls](#controls)
-   [Input format](#input-format)
-   [Configuration](#configuration)
    -   [Line wrapping](#line-wrapping)
    -   [Tab stop](#tab-stop)
    -   [Margins](#margins)
    -   [Auto advancing](#auto-advancing)
    -   [Advanced slide splitting](#advanced-slide-splitting)
    -   [Fragmented slides](#fragmented-slides)
    -   [Theming](#theming)
    -   [Syntax Highlighting](#syntax-highlighting)
    -   [Pandoc Extensions](#pandoc-extensions)
    -   [Images](#images)
    -   [Breadcrumbs](#breadcrumbs)
    -   [Slide numbers](#slide-numbers)
    -   [Evaluating code](#evaluating-code)
    -   [Speaker notes](#speaker-notes)
    -   [Transitions](#transitions)
    -   [Links](#links)
-   [Trivia](#trivia)

Installation
------------

### Pre-built packages

Linux:

- [Archlinux](https://aur.archlinux.org/packages/patat-bin)
- [Debian](https://packages.debian.org/unstable/patat)
- [Fedora](https://src.fedoraproject.org/rpms/patat)
- [NixOS](https://search.nixos.org/packages?show=haskellPackages.patat)
- [openSUSE](https://build.opensuse.org/package/show/openSUSE:Factory:ARM/patat)
- [Ubuntu](https://packages.ubuntu.com/bionic/patat)

Mac OS:

- [Homebrew](https://formulae.brew.sh/formula/patat)

You can also find generic Linux and Mac OS binaries here:
<https://github.com/jaspervdj/patat/releases>.

### From source

`patat` is also available from [Hackage].  You can install it using [cabal] by
running `cabal install patat`.

[cabal]: https://www.haskell.org/cabal/
[Hackage]: https://hackage.haskell.org/package/patat

Running
-------

`patat [*options*] file`

Options
-------

`-w`, `--watch`

:   If you provide the `--watch` flag, `patat` will watch the presentation file
    for changes and reload automatically.  This is very useful when you are
    writing the presentation.

`-f`, `--force`

:   Run the presentation even if the terminal claims it does not support ANSI
    features.

`-d`, `--dump`

:   Just dump all the slides to stdout.  This is useful for debugging.

`--version`

:   Display version information.

Controls
--------

- **Next slide**: `space`, `enter`, `l`, `→`, `PageDown`
- **Previous slide**: `backspace`, `h`, `←`, `PageUp`
- **Go forward 10 slides**: `j`, `↓`
- **Go backward 10 slides**: `k`, `↑`
- **First slide**: `0`
- **Last slide**: `G`
- **Jump to slide N**: `N` followed by `enter`
- **Reload file**: `r`
- **Quit**: `q`

The `r` key is very useful since it allows you to preview your slides while you
are writing them.  You can also use this to fix artifacts when the terminal is
resized.

Input format
------------

The input format can be anything that Pandoc supports.  Plain markdown is
usually the most simple solution:

```markdown
---
title: This is my presentation
author: Jane Doe
...

# This is a slide

Slide contents.  Yay.

---

# Important title

Things I like:

- Markdown
- Haskell
- Pandoc
```

Horizontal rulers (`---`) are used to split slides.

However, if you prefer not use these since they are a bit intrusive in the
markdown, you can also start every slide with a header.  In that case, the file
should not contain a single horizontal ruler.

`patat` will pick the most deeply nested header (e.g. `h2`) as the marker for a
new slide.  Headers _above_ the most deeply nested header (e.g. `h1`) will turn
into title slides, which are displayed as as a slide containing only the
centered title.

This means the following document is equivalent to the one we saw before:

```markdown
---
title: This is my presentation
author: Jane Doe
...

# This is a slide

Slide contents.  Yay.

# Important title

Things I like:

- Markdown
- Haskell
- Pandoc
```

And that following document contains three slides: a title slide, followed by
two content slides.

```markdown
---
title: This is my presentation
author: Jane Doe
...

# Chapter 1

## This is a slide

Slide contents.  Yay.

## Another slide

Things I like:

- Markdown
- Haskell
- Pandoc
```

For more information, see [Advanced slide splitting](#advanced-slide-splitting).

Configuration
-------------

`patat` is fairly configurable.  The configuration is done using [YAML].  There
are several places where you can put your configuration.

1.  For per-user configuration you can use
    `$XDG_CONFIG_DIRECTORY/patat/config.yaml`
    (typically `$HOME/.config/patat/config.yaml`) or `$HOME/.patat.yaml`, for
    example:

    ```yaml
    slideNumber: false
    ```

2.  In the presentation file itself, using the [Pandoc metadata header].
    These settings take precedence over anything specified in the per-user
    configuration file.  They must be placed in a `patat:` section, so they
    don't conflict with metadata:

    ```markdown
    ---
    title: Presentation with options
    author: John Doe
    patat:
        slideNumber: false
    ...

    Hello world.
    ```

3.  In version 0.10 and later slides can be individually configured.
    Within a slide, using a comment starting with `<!--config:`.  These
    settings can override configuration for that specific slide only.
    There should not be any whitespace between `<!--` and `config:`.

    ```markdown
    # First slide

    Slide numbers are turned on here.

    # Second slide

    <!--config:
    slideNumber: false
    -->

    Slide numbers are turned off here.
    ```

    The following settings can **not** be set in a slide configuration block,
    and doing so will result in an error:

     -  `autoAdvanceDelay`
     -  `eval`
     -  `images`
     -  `incrementalLists`
     -  `pandocExtensions`
     -  `slideLevel`
     -  `speakerNotes`

[YAML]: http://yaml.org/
[Pandoc metadata header]: http://pandoc.org/MANUAL.html#extension-yaml_metadata_block

### Line wrapping

Line wrapping can be enabled by setting `wrap: true` in the configuration.  This
will re-wrap all lines to fit the terminal width better.  You can also ask patat
to wrap at a specific column using `wrap: number`, e.g. `wrap: 60`.

### Tab stop

In version 0.12 and later, the amount of spaces a `\t` character in a code block
aligns to can be customized by setting `tabStop: number` in the configuration.
The default is `4`.

### Margins

Margins can be enabled by setting a `margins` entry in the configuration:

```markdown
---
title: Presentation with margins
author: John Doe
patat:
    wrap: true
    margins:
        left: 10
        right: 10
        top: 5
...

Lorem ipsum dolor sit amet, ...
```

This example configuration will generate slides with a margin of 10 columns on
the left, and it will wrap long lines 10 columns before the right side of the
terminal.  Additionally, there will be 5 empty lines in between the title bar
and slide content.

[Line wrapping](#line-wrapping) should be enabled when using non-zero `right`
margin.

By default, the `left` and `right` margin are set to 0, and the `top` margin is
set to 1.

#### Centering

Version 0.11 and later can center content.

 -  To vertically center content, use `top: auto`.
 -  To horizontally center content, use both `left: auto` and `right: auto`.

For example:

```markdown
---
title: Centered presentation
author: John Doe
patat:
    margins:
        left: auto
        right: auto
        top: auto
...

Hello world
```

[Line wrapping](#line-wrapping) is recommended when vertically centering content
if there are any lines that are too wide for the terminal.

### Auto advancing

By setting `autoAdvanceDelay` to a number of seconds, `patat` will automatically
advance to the next slide.

```markdown
---
title: Auto-advance, yes please
author: John Doe
patat:
    autoAdvanceDelay: 2
...

Hello World!

---

This slide will be shown two seconds after the presentation starts.
```

Note that changes to `autoAdvanceDelay` are not picked up automatically if you
are running `patat --watch`.  This requires restarting `patat`.

### Advanced slide splitting

You can control the way slide splitting works by setting the `slideLevel`
variable.  This variable defaults to the least header that occurs before a
non-header, but it can also be explicitly defined.  For example, in the
following document, the `slideLevel` defaults to **2**:

```markdown
# This is a slide

## This is a nested header

This is some content
```

With `slideLevel` 2, the `h1` will turn into a "title slide", and the `h2` will
be displayed at the top of the second slide.  We can customize this by setting
`slideLevel` manually:

```markdown
---
patat:
  slideLevel: 1
...

# This is a slide

## This is a nested header

This is some content
```

Now, we will only see one slide, which contains a nested header.

### Fragmented slides

By default, slides are always displayed "all at once".  If you want to reveal
them fragment by fragment, there are two ways to do that.  The most common
case is that lists should be displayed incrementally.

This can be configured by settings `incrementalLists` to `true` in the metadata
block:

```markdown
---
title: Presentation with incremental lists
author: John Doe
patat:
    incrementalLists: true
...

- This list
- is displayed
- item by item
```

Setting `incrementalLists` works on _all_ lists in the presentation.  To flip
the setting for a specific list, wrap it in a block quote.  This will make the
list incremental if `incrementalLists` is not set, and it will display the list
all at once if `incrementalLists` is set to `true`.

This example contains a sublist which is also displayed incrementally, and then
a sublist which is displayed all at once (by merit of the block quote).

```markdown
---
title: Presentation with incremental lists
author: John Doe
patat:
    incrementalLists: true
...

- This list
- is displayed

    * item
    * by item

- Or sometimes

    > * all at
    > * once
```

Another way to break up slides is to use a pagraph only containing three dots
separated by spaces.  For example, this slide has two pauses:

```markdown
Legen

. . .

wait for it

. . .

Dary!
```

### Theming

Colors and other properties can also be changed using this configuration.  For
example, we can have:

```markdown
---
author: 'Jasper Van der Jeugt'
title: 'This is a test'
patat:
    wrap: true
    theme:
        emph: [vividBlue, onVividBlack, italic]
        strong: [bold]
        imageTarget: [onDullWhite, vividRed]
...

# This is a presentation

This is _emph_ text.

![Hello](foo.png)
```

The properties that can be given a list of styles are:

`blockQuote`, `borders`, `bulletList`, `codeBlock`, `code`, `definitionList`,
`definitionTerm`, `emph`, `header`, `imageTarget`, `imageText`, `linkTarget`,
`linkText`, `math`, `orderedList`, `quoted`, `strikeout`, `strong`,
`tableHeader`, `tableSeparator`, `underline`

The accepted styles are:

`bold`, `italic`, `dullBlack`, `dullBlue`, `dullCyan`, `dullGreen`,
`dullMagenta`, `dullRed`, `dullWhite`, `dullYellow`, `onDullBlack`,
`onDullBlue`, `onDullCyan`, `onDullGreen`, `onDullMagenta`, `onDullRed`,
`onDullWhite`, `onDullYellow`, `onVividBlack`, `onVividBlue`, `onVividCyan`,
`onVividGreen`, `onVividMagenta`, `onVividRed`, `onVividWhite`, `onVividYellow`,
`underline`, `vividBlack`, `vividBlue`, `vividCyan`, `vividGreen`,
`vividMagenta`, `vividRed`, `vividWhite`, `vividYellow`

Also accepted are styles of the form `rgb#RrGgBb` and `onRgb#RrGgBb`, where `Rr`
`Gg` and `Bb` are hexadecimal bytes (e.g. `rgb#f08000` for an orange foreground,
and `onRgb#101060` for a deep purple background).  Naturally, your terminal
needs to support 24-bit RGB for this to work.  When creating portable
presentations, it might be better to stick with the named colours listed above.

To customize the color of the `underline`, combine the prefix with a color, for
example:

```yaml
patat:
    theme:
        strong: [underline, underlineVividBlue]
```

### Syntax Highlighting

`patat` uses [Kate] Syntax Highlighting files.  `patat` ships with support for
nearly one hundred languages thanks to Pandoc.  However, if your language is
not yet available, you can add the highlighting XML file in the settings:

```markdown
---
patat:
  syntaxDefinitions:
  - 'impurescript.xml'
...

...
```

As part of theming, syntax highlighting is also configurable.  This can be
configured like this:

```markdown
---
patat:
  theme:
    syntaxHighlighting:
      decVal: [bold, onDullRed]
...

...
```

`decVal` refers to "decimal values".  This is known as a "token type".  For a
full list of token types, see [this list] -- the names are derived from there in
an obvious way.

[this list]: https://hackage.haskell.org/package/highlighting-kate-0.6.3/docs/Text-Highlighting-Kate-Types.html#t:TokenType

Note that in order to get syntax highlighting to work, you should annotate code
blocks with the language, e.g. using a fenced code block:

    ```ruby
    puts "Hello, world!"
    ```

### Pandoc Extensions

Pandoc comes with a fair number of extensions on top of markdown, listed [here](https://hackage.haskell.org/package/pandoc-2.0.5/docs/Text-Pandoc-Extensions.html).

`patat` enables a number of them by default, but this is also customizable.

In order to enable an additional extensions, e.g. `autolink_bare_uris`, add it
to the `pandocExtensions` field in the YAML metadata:

```markdown
---
patat:
  pandocExtensions:
    - patat_extensions
    - autolink_bare_uris
...

Document content...
```

The `patat_extensions` in the above snippet refers to the default set of
extensions enabled by `patat`.  If you want to disable those and only use a
select few extensions, simply leave it out and choose your own:

```markdown
---
patat:
  pandocExtensions:
    - autolink_bare_uris
    - emoji
...

Document content...
```

If you don't want to enable any extensions, simply set `pandocExtensions` to the
empty list `[]`.


### Images

#### Native Images support

Version 0.8 and later include images support for some terminal emulators.

```markdown
---
patat:
  images:
    backend: auto
...

# A slide with only an image.

![](matterhorn.jpg)
```

`patat` can display full-size images on slides. For this to work `images` must be enabled in the configuration and the slide needs to contain only a single image and no other content. The image will be centered and resized to fit the terminal window.

`images` is off by default in the configuration.

`patat` supports the following image drawing backends:

-   `backend: iterm2`: uses [iTerm2](https://iterm2.com/)'s special escape
    sequence to render the image.  This even works with animated GIFs!
    Note that it can have issues running under `tmux`.

-   `backend: kitty`: uses
    [Kitty's icat command](https://sw.kovidgoyal.net/kitty/kittens/icat.html).

-   `backend: wezterm`: uses the iTerm2 image protocol as implemented by
    WezTerm.

-   `backend: w3m`: uses the `w3mimgdisplay` executable to draw directly onto
    the window.  This has been tested in `urxvt` and `xterm`, but is known to
    produce weird results in `tmux`.

    If `w3mimgdisplay` is in a non-standard location, you can specify that using
    `path`:

    ```yaml
    backend: 'w3m'
    path: '/home/jasper/.local/bin/w3mimgdisplay'
    ```

#### Images using Evaluation

Rather than using the built-in image support, you can also use programs that
write ASCII escape codes directly to the screen with
[code evaluation](#evaluating-code).

In order to do that, for example, we could configure `kitten` code snippets
to evaluate using [Kitty]'s command `icat`.  This uses the `none` container
setting to ensure that the resulting output is not wrapped in a code block,
and the `reveal` and `replace` settings immediately replace the snippet.

    ---
    patat:
      eval:
        kitten:
          command: sed 's/^/kitten /' | bash
          replace: true
          reveal: false
          container: none
    ...

    See, for example:

    ```kitten
    icat --align left dank-meme.jpg
    ```

### Breadcrumbs

By default, `patat` will print a breadcrumbs-style header, e.g.:

    example.md > This is a title > This is a subtitle

This feature can be turned off by using:

```yaml
patat:
  breadcrumbs: false
```

### Slide numbers

By default, `patat` will display slide number in bottom-right corner

This feature can be turned off by using:

```yaml
patat:
  slideNumber: false
```

### Evaluating code

`patat` can evaluate code blocks and show the result.  You can register an
_evaluator_ by specifying this in the YAML metadata:

    ---
    patat:
      eval:
        ruby:
          command: irb --noecho --noverbose
          reveal: true  # Optional
          replace: false  # Optional
          container: code  # Optional
          syntax: json  # Optional
    ...

    Here is an example of a code block that is evaluated:

    ```ruby
    puts '{"hello": "world"}'
    ```

An arbitrary amount of evaluators can be specified, and whenever a a class
attribute on a code block matches the evaluator, it will be used.

**Note that executing arbitrary code is always dangerous**, so double check the
code of presentations downloaded from the internet before running them if they
contain `eval` settings.

Aside from the command, there are five more options:

 -  `reveal`: Introduce a pause (see [fragments](#fragmented-slides)) in
    between showing the original code block and the output.  Defaults to `true`.
 -  `replace`: Remove the original code block and replace it with the output
    rather than appending the output in a new code block.  Defaults to `false`.
 -  `container`: By default, the output is wrapped in a code block again with
    the original syntax highlighting.  You can customize this behaviour by
    setting `container` to:
     *  `code`: the default setting.
     *  `none`: no formatting applied.
     *  `inline`: no formatting applied and no trailing newline.
 -  `syntax`: When using `container: code` (the default), the output of the eval
    block will use the same syntax highlighting as the input code block.
    You can customize this using `syntax`, e.g. `syntax: json`.
 -  `stderr`: Include output from standard error.  Defaults to `true`.

 -  `wrap`: this is a deprecated name for `container`, used in version 0.11 and
    earlier.
 -  `fragment`: this is a deprecated name for `reveal`, used in version 0.13 and
    earlier.

Note that it is possible to set multiple classes on a codeblock by using pandoc
fenced code block syntax.  This allows you to to separate syntax highlighting
from evaluation.  You can use this to only evaluate certain snippets, or even
evaluate using different commands or settings:

    ---
    patat:
      eval:
        python2:
          command: python2
        python3:
          command: python3
    ...

    Snippet evaluated using an old python version:

    ~~~{.python .python2}
    print "Hello, world"
    ~~~

    Snippet evaluated using a more recent python version:

    ~~~{.python .python3}
    print("Hello, world")
    ~~~

Setting `reveal: false` and `replace: true` offers a way to "filter" code
blocks, which can be used to render ASCII graphics.

    ---
    patat:
      eval:
        figlet:
          command: figlet
          reveal: false
          replace: true
    ...

    ```figlet
    Fancy Font
    ```

This feature works by simply by:

1.  Spawn a process with the provided command
2.  Write the contents of the code block to the `stdin` of the process
3.  Wait for the process to exit
4.  Render the `stdout` of the process

### Speaker Notes

Version 0.9 and later support comments which can be used as speaker notes.

```markdown
---
title: This is my presentation
author: Jane Doe
...

# Chapter 1

<!--
Note: I should not bore the audience with my thoughts on powerpoint but
just get straight to the point.
-->

Slide contents.  Yay.

<!-- TODO: Finish the rest of the presentation. -->
```

You can also configure `patat` to write the speaker notes for the current slide
to a file whenever the slide changes:

```yaml
patat:
  speakerNotes:
    file: /tmp/notes.txt
```

Then, you can display these in a second terminal (presumably on a second
monitor) by just displaying this file whenever it changes. `tail` is a primitive
way of doing that:

```bash
tail -F /tmp/notes.txt
```

Alternatively, just use a second `patat` instance with `--watch` enabled:

```bash
patat -w /tmp/notes.txt
```

Note that speaker notes should not start with `<!--config:`, since then they
will be parsed as [configuration](#configuration) blocks.  They are allowed
to start with `<!-- config:`; the lack of whitespace matters.

### Transitions

Version 0.10 and later support transitions in between slides.  A relatively
fast terminal emulator (e.g. [Alacritty], [Kitty], [iTerm2]) is suggested when
enabling this, to avoid too much flickering -- some flickering is unavoidable
since we redraw the entire screen on each frame.

```yaml
patat:
  transition:
    type: slideLeft
```

To set transitions on specific slides, use `<!--config:` blocks, as detailed
in the [configuration section](#configuration).  For example:

```markdown
# Slide one

Slide one content.

# Slide two

<!--config:
transition:
  type: slideLeft
  duration: 2
-->

Slide two content.
```

Supported transitions `type`s:

 -  `slideLeft`: slides the new slide in from right to left.
 -  `dissolve`: changes characters over time.
 -  `matrix`: loosely inspired by the 1999 science fiction movie.

All transitions currently take these arguments:

 -  `frameRate`: number of frames per second.  Defaults to 24.
 -  `duration`: duration of the animation in seconds.  Defaults to 1.

#### Random transitions

You can set `type` to `random` to randomly pick a transition effect.

```yaml
patat:
  transition:
    type: random
    items:
    - type: dissolve
      duration: 3
    - type: slideLeft
      frameRate: 10
```

You can optionally set `items` to a non-empty list of transition effects to
randomly sample from.  If `items` is not set, `patat` will simply sample from
all transition effects using their respective default settings.

### Links

Version 0.15.0.0 and later support [OSC8] for hyperlinks.  This makes hyperlinks
clickable in many terminal emulators (see [OSC8 adoption]).

There is currently no way to detect if a terminal supports this feature, so you
need to explicitly turn this on in the configuration:

```yaml
patat:
  links:
    osc8: true
```

[OSC8]: https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
[OSC8 adoption]: https://github.com/Alhadis/OSC8-Adoption

Trivia
------

_"Patat"_ is the Flemish word for a simple potato.  Dutch people also use it to
refer to French Fries but I don't really do that -- in Belgium we just call
fries _"Frieten"_.

The idea of `patat` is largely based upon [MDP] which is in turn based upon
[VTMC].  I wanted to write a clone using Pandoc because I ran into a markdown
parsing bug in MDP which I could not work around.  A second reason to do a
Pandoc-based tool was that I would be able to use [Literate Haskell] as well.
Lastly, I also prefer not to install Node.js on my machine if I can avoid it.

[MDP]: https://github.com/visit1985/mdp
[VTMC]: https://github.com/jclulow/vtmc
[Literate Haskell]: https://wiki.haskell.org/Literate_programming

[Alacritty]: https://alacritty.org/
[iTerm2]: https://iterm2.com/
[Kitty]: https://sw.kovidgoyal.net/kitty/
