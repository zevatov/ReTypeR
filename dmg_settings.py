import os.path

# Path to the app bundle to be packaged
app_path = defines.get("app", "dist/ReTypeR.app")
app_name = os.path.basename(app_path)

# Disk image format
format = "UDBZ"

# Files to copy into the root of the DMG
files = [app_path]

# Symlinks to create in the root of the DMG
symlinks = {
    "Applications": "/Applications"
}

# Background image of the DMG window
background = "dmg_background.png"

# Volume icon of the mounted DMG
icon = "icon.icns"

# Size of icons (in points)
icon_size = 120

# Size of label text (in points)
text_size = 12

# Hide Finder window extra UI elements to avoid showing white spaces or sidebar gaps
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False

# Window position and size (top-left coordinates, width and height)
# Window size matches background dimensions (660x480)
# Y increases bottom-to-top for window_rect.
window_rect = ((200, 120), (660, 480))

# Positions of the icons relative to the top-left of the window interior.
# Centered horizontally: 180 and 480 (distance 300 points).
# Centered vertically: Y=240 (exactly half of window height).
# Y increases top-to-bottom.
icon_locations = {
    app_name: (180, 240),
    "Applications": (480, 240)
}
