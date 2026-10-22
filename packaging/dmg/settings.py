# Adapted from Fly Media AppleTree's drag-to-Applications installer (GPLv3).
files = [defines['app']]
symlinks = {'Applications': '/Applications'}
background = defines['background']
icon = defines['icon']
# FinderInfo changes inside a signed app invalidate strict signature checks.
# In particular, do not set hide_extensions.
icon_locations = {'Neutron.app': (168, 190), 'Applications': (492, 190)}
format = 'UDZO'
filesystem = 'HFS+'
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
default_view = 'icon-view'
# Leave room for Finder's global path/status bars when user preferences override
# the per-image visibility settings. All instructions fit in the first 400 points.
window_rect = ((200, 120), (660, 480))
icon_size = 128
text_size = 12
label_pos = 'bottom'
