## 3.0.2
* Patch 8.2.5 (but should work in classic too).
* Added an option to set a fixed width for a bar.
* Added an option to change background colors per bar and globally.

## 3.0.1
* TOC bump for patch 8.2.0.
* Classic compability mods, same version should work for both retail and classic now.

## 3.0.0
* Updated for Battle for Azeroth.

## 2.0.9
* TOC bump for patch 7.3.0.
* Fixed PlaySound issue.

## 2.0.8
* Fixed bug caused by previous update.

## 2.0.7
* Added option to toggle visibility of the text per module.
* Fixed error where some slower to load data broker modules wouldn't sometimes be added on screen at all.

## 2.0.6
* TOC bump.
* Remove spaces from Candy bar frame names.

## 2.0.5
* Added caching for compiled callbacks to lower memory usage.
* Fixed visibility clearing actually clearing text filter instead. Oops.
* Fixed script validation. It previously let through any syntactically valid code that still wouldn't work. Now it performs proper checks and will block code that won't work or would cause errors.

## 2.0.4
* Fixed error if user supplied text filter returned invalid result.
* Added warnings if custom callback result is unexpected. Additionally text filter now displays current callback output on validation.

## 2.0.3
* Fixed error with fade in and out animations if visibility status changed while animation was still playing.
* Tweaking frame hiding some more.

## 2.0.2
* Fixed error caused by hide on protected frames.

## 2.0.1
* Added a way to remove active bars in options menu.
* Fixed yet another module icon nil error.
* Updated AceLibs.

## 2.0.0
* Legion update (no major changes).
* Fixed icon update bug.

## 1.0.3
* Really properly fix the parent anchoring error.

## 1.0.2
* Improved compability with non-standard DataBroker modules by displaying `label` if `text` doesn't exist.
* Fix to missing parent anchor in case a module is not loaded.

## 1.0.1
* Fixed a nil error with module icon in options menu.
