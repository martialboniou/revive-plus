Context
=======

Window configuration is available in Emacs as a hard coded function (in C) and doesn't provide serialization. You can register window configuration, copy-paste it in session but you have no persistence strategy. `revive.el` provided by [HIROSE Yuuji](http://www.gentei.org/~yuuji) is a great tool as window configuration is rewritten in Emacs Lisp and fully supports saving and restoring.

Unfortunately `revive.el` doesn't provide frames support and other things useful in modern Emacs.

Goal
====

`revive-plus` extends `revive.el` by enabling:

* window focus memorization;
* frames restoration;
* `escreen` support;
* special case saving like [`ECB`](http://ecb.sourceforge.net/).

Install
=======

From git
--------

    git clone https://github.com/martialboniou/revive-plus.git

With el-get
-----------

Add this [recipe](https://github.com/martialboniou/el-get/blob/master/recipes/revive-plus.rcp) to your personal recipe directory.

Remember that if you want to add a directory for `el-get` recipes, write:

    (add-to-list 'el-get-recipe-path "<my-favorite-recipes-directory>")

If you install this package with `el-get` or any auto-installer, you probably don't need to add the `(require revive+)` recommended in the following setup as the main interactive or setup functions are made available to *autoloading*.

Setup
=====

    (require 'revive+) ; may be optional
    (revive-plus:demo)

You may customize revive-plus:all-frames to save all frames:

    (require 'revive+) ; may be optional
    (setq revive-plus:all-frames t)
    (revive-plus:demo)

Usage
=====

After calling `(revive-plus:demo)` or `(revive-plus:minimal-setup)`,
your window configuration is **automatically** saved on Emacs killing
and restore at Emacs startup. The file *~/.emacs.d/last-wconf* is
used for this. If you want to prevent crashes by periodically
autosave the latest window configuration you just need to ensure
`desktop` is auto-saved:

    (add-hook 'auto-save-hook #'(lambda () (call-interactively #'desktop-save)))

Remember: there are two functions to save window configurations:

* `#'CURRENT-WINDOW-CONFIGURATION-PRINTABLE`: save the windows only (used by `<f6>` keys in *demo* mode);
* `#'WINDOW-CONFIGURATION-PRINTABLE`: save the windows for all escreens and, if `REVIVE-PLUS:ALL-FRAMES` is set to true, in all frames too.

If `REVIVE-PLUS:ALL-FRAMES` is `NIL` and `escreen` is not enabled in your
init file (ie. *~/.emacs*), those two functions behave the same.

Additional functions are available:

* `<f6><f6>`: save the current window configuration (no frames / no `escreen`, only the displayed windows in the current frame);
* `<f6><f5>`: restore the previously saved configuration;
* `<f6>2` .. `<f6>0`: restore the *second* to *tenth* window configuration.

All the last ten window configurations saved via `<f6>` keys are stored
in the file *~/.emacs.d/wconf-archive* and will be loaded at Emacs startup.
This functionality is useful to transfer a window configuration to another
frame, for example.

* `<f5><f5>`: switch from a window configuration with multiple windows to a single view and back. Useful to focus on a buffer.

This functionality uses the standard window configuration system because
there's no need to save it between sessions. The marker position is
not saved so you won't lose your position when toggling back.

**Beware:** If you use Emacs in `NO-WINDOW-SYSTEM` (ie. in a terminal), you
lose the window configuration in the other frames than the
last focused one. If `escreen` is enabled, all the content of
those other frames is restored as new ESCREEN. Eg.:

* `WINDOW-SYSTEM` (saving):

    -------------     -------------     -----------
    |  frame 2  |     |  frame 1  |     | frame 3 |
    |           |  +  |           |  +  |         |
    | ( 0 1 2 ) |     | ( 0 1 2 ) |     | ( 0 1 ) |
    -------------     -------------     -----------

where `frame 1` is the focused (aka. selected) frame and `( X Y )`s are the `ESCREEN`s.

* `NO-WINDOW-SYSTEM` (restoring):

    -----------------------
    |     * no-frame *    |
    |                     |
    | ( 0 1 2 4 5 6 7 8 ) |
    -----------------------

where:

* `( 0 1 2 )` is the `( 0 1 2 )` in `frame 1`;
* `( 4 5 6 )` is the `( 0 1 2 )` in `frame 2`;
* `( 7 8 )` is the `( 0 1 )` in `frame 3`.
