#!/usr/bin/env python3
"""Add whisper.xcframework to Xcode project linking."""
import sys, re

pbxproj = "/Users/doxie/Github/BasketballRecord/Basketland.xcodeproj/project.pbxproj"

# Read entire project.pbxproj
with open(pbxproj) as f:
    content = f.read()

whisper_ref_id = "WHISPER00000000000000000001"
whisper_build_id = "WHISPER00000000000000000002"

# 1. Add PBXFileReference (if not present)
if whisper_ref_id not in content:
    ref_entry = f"""
{whisper_ref_id} /* whisper.xcframework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; name = whisper.xcframework; path = "Frameworks/whisper.xcframework"; sourceTree = "<group>"; }};"""
    content = content.replace(
        "/* End PBXFileReference section */",
        ref_entry + "\n/* End PBXFileReference section */"
    )

# 2. Add PBXBuildFile (if not present)
if whisper_build_id not in content:
    build_entry = f"""
{whisper_build_id} /* whisper.xcframework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {whisper_ref_id} /* whisper.xcframework */; }};"""
    content = content.replace(
        "/* End PBXBuildFile section */",
        build_entry + "\n/* End PBXBuildFile section */"
    )

# 3. Add build file to Frameworks build phase
# Find the Frameworks build phase and add our file ref
fb_phase_pattern = r'([A-F0-9]{24}|BR[A-F0-9]{20}) \/\* Frameworks \*\/ = \{\n\tisa = PBXFrameworksBuildPhase;\n\tbuildActionMask = .*?;\n\t\tfiles = \((.*?)\);'
def add_to_phase(m):
    prefix = m.group(1)
    files_content = m.group(2)
    if whisper_build_id not in files_content:
        files_content += f"\n\t\t\t\t{whisper_build_id} /* whisper.xcframework in Frameworks */,"
    return f'{prefix} /* Frameworks */ = {{\n\tisa = PBXFrameworksBuildPhase;\n\tbuildActionMask = 2147483647;\n\t\tfiles = ({files_content}\n\t\t);'
content = re.sub(fb_phase_pattern, add_to_phase, content, flags=re.DOTALL)

# 4. Add to Frameworks group
group_pattern = r'([A-F0-9]{24}|BR[A-F0-9]{20}) \/\* Frameworks \*\/ = \{\n\tisa = PBXGroup;\n\tchildren = \((.*?)\);'
def add_to_group(m):
    gid = m.group(1)
    children = m.group(2)
    if whisper_ref_id not in children:
        children += f"\n\t\t\t\t{whisper_ref_id} /* whisper.xcframework */,"
    return f'{gid} /* Frameworks */ = {{\n\tisa = PBXGroup;\n\tchildren = ({children}\n\t\t\t);'
content = re.sub(group_pattern, add_to_group, content, flags=re.DOTALL)

# 5. Add framework search path to Debug and Release
for config in ["Debug", "Release"]:
    marker = f'/* {config} */'
    fw_path = '\n\t\t\t\tFRAMEWORK_SEARCH_PATHS = (\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"$(PROJECT_DIR)/Frameworks",\n\t\t\t\t);'
    # Insert before GENERATE_INFOPLIST_FILE in each config section
    content = content.replace(
        f'{marker}\n\t\t\t\tCURRENT_PROJECT_VERSION',
        f'{marker}\n\t\t\t\tCURRENT_PROJECT_VERSION'
    )

with open(pbxproj, 'w') as f:
    f.write(content)

print("Done. Added whisper framework to project.")
