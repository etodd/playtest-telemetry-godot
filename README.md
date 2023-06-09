# Playtest Telemetry

A [playtest telemetry](https://github.com/playtest-telemetry-server) plugin for Godot.

1. Copy the PlaytestTelemetry directory into your `addons` folder.

2. Under Project -> Project Settings -> Plugins, enable the PlaytestTelemetry plugin.

3. Under Project -> Project Settings -> General, enable "Advanced settings", search for "Playtest Telemetry", and enter the URL and API key for your telemetry server. Make sure to specify a version number too. It's important to distinguish each version of your game that you send out to playtesters.

4. Anywhere in your code where you are currently doing this:
	```
	get_tree().quit()
	```
	You need to change it to this:
	```
	get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	```

5. Under Project -> Export..., in the Features tab of each preset, add `telemetry` to the Custom features field.

6. Export your game and run it, then open up the domain name of your telemetry server in a web browser, and enjoy!
