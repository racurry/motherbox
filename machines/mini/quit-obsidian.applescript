-- Quits Obsidian if it is running.

tell application "System Events"
	set isRunning to (name of processes) contains "Obsidian"
end tell

if isRunning then
	quit application "Obsidian"
	delay 5
end if
