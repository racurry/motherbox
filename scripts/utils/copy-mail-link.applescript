-- Copies a deep link to the message currently selected in Mail.app.
--
-- Mail understands message://<Message-ID> URLs; clicking one opens that exact
-- message. This grabs the selected message's ID, builds the URL, puts it on the
-- clipboard, and also returns it on stdout (so a caller like `osascript` or a
-- macOS Shortcut can reuse the value).
--
-- Usage:
--   osascript ~/.config/motherbox/scripts/utils/copy-mail-link.applescript
--
-- Intended to be wired to a macOS Shortcut + hotkey via a "Run Shell Script"
-- action that runs the osascript command above.

tell application "Mail"
	set sel to selection
	if sel is {} then
		display notification "Select a message first" with title "Copy Mail Link"
		error "No message selected"
	end if
	set msgID to message id of (item 1 of sel)
end tell

set theURL to "message://%3c" & msgID & "%3e"
set the clipboard to theURL
display notification theURL with title "Mail link copied"
return theURL
