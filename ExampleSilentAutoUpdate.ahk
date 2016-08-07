#SingleInstance force
#Include AutoUpdate.ahk

updateIntervalDays := 0
FILE := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/ExampleSilentAutoUpdate.ahk"
CHANGELOG_URL := "https://raw.githubusercontent.com/stealzy/AutoUpdate/master/CHANGELOG.md"
VERSION_REGEX := "Oi)(?<=Version )?(\d+(?:\.\d+)?)"
WhatNew_REGEX := "Ois)(?<=----)\R(.*?)(\R\R|$)"

AutoUpdate(FILE,, updateIntervalDays, [CHANGELOG_URL, VERSION_REGEX, WhatNew_REGEX])