#!/usr/bin/env python3
"""Local checks, not a substitute for App Store Connect validation."""
from pathlib import Path
import plistlib, subprocess, sys
app=Path(sys.argv[1])
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert '$(' not in str(info), 'Unexpanded Info.plist build setting'
subprocess.run(['codesign','--verify','--strict',str(app)],check=True)
result=subprocess.run(['codesign','-d','--entitlements','-','--xml',str(app)],check=True,capture_output=True)
raw=result.stdout
start=raw.find(b'<?xml')
if start < 0: start=raw.find(b'<plist')
assert start >= 0, 'Missing signed entitlements'
permissions=plistlib.loads(raw[start:])
assert permissions.get('com.apple.security.app-sandbox') is True, 'Sandbox missing'
assert not permissions.get('com.apple.security.get-task-allow'), 'Debug entitlement in release'
assert not any('temporary-exception' in k or 'apple-events' in k for k in permissions), 'Unexpected automation entitlement'
assert not any(permissions.get(k) for k in ['com.apple.security.network.client','com.apple.security.network.server']), 'Unexpected network access'
icon = info['CFBundleIconFile']
icon = icon if icon.endswith('.icns') else icon + '.icns'
assert (app/'Contents/Resources'/icon).is_file(), 'Icon missing'
privacy=plistlib.loads((app/'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
binary=app/'Contents/MacOS'/info['CFBundleExecutable']
symbols=subprocess.check_output(['nm','-u',str(binary)],text=True)
for api in ['_AXUIElement', '_AXIsProcessTrusted','_CGEventTapCreate','_CGEventPost']:
    assert api not in symbols, f'Removed capability still linked: {api}'
print('Verified sandbox, icon, privacy manifest, and absence of cross-app AX/event injection symbols.')
print('Bundle:', info['CFBundleIdentifier'], 'Version:', info['CFBundleShortVersionString'], info['CFBundleVersion'])
