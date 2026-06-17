• The * key was going to Roku’s built-in Video options menu because the Video node had focus.

  I patched the scene to keep focus on MainScene and disable the Video UI when supported:

  - after init
  - after starting playback
  - whenever video enters playing

  Rebuilt successfully.

  Reinstall:

  ROKU_DEV_TARGET=192.168.0.2 ROKU_DEV_PASSWORD='rokudev' make install-debug

  Expected now:

  [OnlyAds] Key pressed: options
  [OnlyAds] Showing options dialog

  and you should see the app’s Options dialog with About, not the Roku captions menu.


• Fixed the warning in source/main.brs by using the created scene:

  scene = screen.CreateScene("MainScene")
  scene.SetFocus(true)

  Rebuilt successfully.

• * is being taken by Roku’s native video player options on your device, so the app cannot reliably use it while Video playback is active.

  I changed the app so About is accessible without *:

  - OK opens About
  - Up opens About
  - Play/Pause controls pause/resume
  - Added a persistent top-right hint: OK: About
  - When About opens, playback pauses so the dialog can render above video, then resumes after closing

  Rebuilt successfully. Install:

  ROKU_DEV_TARGET=192.168.0.2 ROKU_DEV_PASSWORD='rokudev' make install-debug



• Updated the About dialog to show:

  Status: Paused
  Developed by: gressware.ai
  Version 1.1

  Rebuilt successfully.

